import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../core/models/library_item.dart';
import '../library/library_repository.dart';

/// Handler `audio_service` unique pour toute l'app — lecture audiobook en
/// arrière-plan, notification/lockscreen, chapitres (07_READER_AUDIOBOOK.md).
///
/// [Trou comblé — audit V1] `audio_service` figurait dans pubspec.yaml comme
/// dépendance mais n'était jamais importé nulle part : fermer l'écran ou
/// éteindre l'écran coupait la lecture, aucun service de premier plan
/// n'existait. Ce handler est créé UNE SEULE FOIS dans main() via
/// `AudioService.init()` (jamais dans le widget de l'écran, sinon il serait
/// recréé/détruit à chaque navigation et perdrait tout l'intérêt d'un
/// service persistant) et injecté via Provider.
///
/// [Décision] AudioPlayerScreen NE crée plus son propre `AudioPlayer()` — il
/// lit `player` directement depuis ce handler pour tous les streams UI
/// (position, durée, état de lecture) et appelle les méthodes de ce handler
/// pour toute action qui doit rester synchronisée avec la notification
/// (vitesse, sauvegarde de position). `play()`/`pause()`/`seek()` peuvent en
/// revanche être invoqués directement sur `player` : `_broadcastState` est
/// câblé sur `player.playbackEventStream`, donc la notification se met à
/// jour quelle que soit l'origine de l'appel (UI ou lockscreen).
class AudiobookHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer player = AudioPlayer();

  LibraryRepository? _repository;
  String? _itemId;
  double _readProgress = 0;
  Timer? _saveTimer;

  /// [Correctif LibriVox] Un livre audio LibriVox arrive souvent en dizaines
  /// de MP3 séparés (pas un seul M4B) — logique reprise telle quelle de
  /// l'ancien `_loadAudiobook()` de AudioPlayerScreen, déplacée ici pour
  /// survivre à la fermeture de l'écran.
  List<File> _files = [];
  List<File> get chapterFiles => _files;

  AudiobookHandler() {
    player.playbackEventStream.listen(_broadcastState, onError: (Object e, StackTrace st) {
      // [Correctif] Une erreur de lecture (fichier corrompu, ex.) ne doit pas
      // faire planter tout le handler audio_service pour le reste de la
      // session — juste remonter en idle.
      playbackState.add(playbackState.value.copyWith(processingState: AudioProcessingState.error));
    });
    player.currentIndexStream.listen((index) {
      if (index != null) mediaItem.add(_mediaItemFor(index));
    });
  }

  /// Charge un nouvel item — sauvegarde d'abord la position de l'item
  /// précédent s'il y en avait un (changement de livre sans fermer l'app).
  Future<void> loadItem(LibraryItem item, LibraryRepository repository) async {
    if (_itemId != null && _itemId != item.id) {
      await _savePosition();
    }
    _saveTimer?.cancel();
    _repository = repository;
    _itemId = item.id;
    _readProgress = item.readProgress;
    _files = [];

    final path = item.localPath;
    if (path == null) {
      throw StateError('noLocalFile');
    }

    final dir = Directory(path);
    if (await dir.exists()) {
      _files = (await dir.list().toList())
          .whereType<File>()
          .where((f) => f.path.endsWith('.mp3'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path)); // ordre alphabétique = ordre des chapitres

      if (_files.isEmpty) {
        throw StateError('noAudioFiles');
      }

      queue.add([for (var i = 0; i < _files.length; i++) _mediaItemForFile(item, i)]);

      await player.setAudioSource(
        ConcatenatingAudioSource(children: _files.map((f) => AudioSource.uri(Uri.file(f.path))).toList()),
      );
    } else {
      queue.add([_mediaItemForFile(item, 0)]);
      await player.setAudioSource(AudioSource.uri(Uri.file(path))); // M4B unique
    }

    mediaItem.add(_mediaItemFor(player.currentIndex ?? 0));

    await player.setSpeed(item.playbackSpeedPref ?? 1.0);

    // Reprise (index fichier, position ms) — pas juste une valeur en secondes,
    // sinon la reprise pointe vers le mauvais chapitre après réouverture d'un
    // livre LibriVox multi-fichiers.
    final saved = _parseStoredPosition(item.lastCfi);
    if (saved != null) {
      await player.seek(Duration(milliseconds: saved.positionMs), index: saved.fileIndex);
    }

    // Toutes les 10s : sauvegarder (index fichier courant, position ms). Un
    // Timer périodique, pas un throttle sur positionStream (qui émet
    // plusieurs fois par seconde) — et ce timer survit maintenant à la
    // fermeture de l'écran puisqu'il vit dans ce handler, pas dans le widget.
    _saveTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _updateProgress();
      unawaited(_savePosition());
    });
  }

  void _updateProgress() {
    final duration = player.duration;
    final position = player.position;
    if (duration != null && duration.inMilliseconds > 0) {
      _readProgress = (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
    }
  }

  MediaItem _mediaItemFor(int index) {
    if (queue.value.isEmpty) {
      return const MediaItem(id: 'unknown', title: '');
    }
    return queue.value[index.clamp(0, queue.value.length - 1)];
  }

  MediaItem _mediaItemForFile(LibraryItem item, int index) {
    final artUri = item.coverPath != null ? Uri.file(item.coverPath!) : null;
    final chapterSuffix = _files.length > 1 ? ' — ${index + 1}/${_files.length}' : '';
    // [Correctif] `item.durationS` est la duree du LIVRE ENTIER, pas celle de
    // ce fichier/chapitre precis -- l'utiliser ici afficherait une barre de
    // progression fausse dans la notification pour tout livre multi-fichiers.
    // audio_service/just_audio mettent de toute facon a jour la duree reelle
    // via le stream de lecture une fois le fichier charge ; pas la peine de
    // fournir une valeur approximative ici.
    return MediaItem(
      id: '${item.id}#$index',
      title: item.title,
      artist: item.author,
      artUri: artUri,
      album: '${item.title}$chapterSuffix',
      duration: _files.length <= 1 && item.durationS != null ? Duration(seconds: item.durationS!) : null,
    );
  }

  Future<void> _savePosition() async {
    final repository = _repository;
    final itemId = _itemId;
    if (repository == null || itemId == null) return;
    final index = player.currentIndex ?? 0;
    final positionMs = player.position.inMilliseconds;
    await repository.updatePosition(
      itemId,
      readProgress: _readProgress,
      lastCfi: '$index:$positionMs',
    );
  }

  ({int fileIndex, int positionMs})? _parseStoredPosition(String? raw) {
    if (raw == null || !raw.contains(':')) return null;
    final parts = raw.split(':');
    final fileIndex = int.tryParse(parts[0]);
    final positionMs = int.tryParse(parts[1]);
    if (fileIndex == null || positionMs == null) return null;
    return (fileIndex: fileIndex, positionMs: positionMs);
  }

  /// Vitesse de lecture — persistée par livre (NF-023). Passe par le handler
  /// (pas directement `player.setSpeed`) pour que la persistance et la
  /// notification restent au même endroit que le reste de la logique de
  /// session.
  Future<void> setPlaybackSpeed(double speed) async {
    await player.setSpeed(speed);
    final repository = _repository;
    final itemId = _itemId;
    if (repository != null && itemId != null) {
      await repository.updatePlaybackSpeed(itemId, speed);
    }
  }

  /// Saute au fichier/chapitre `index` de la queue courante — navigation par
  /// chapitre (trou identifié dans l'audit : aucune UI de navigation par
  /// chapitre n'existait).
  Future<void> jumpToChapter(int index) async {
    await player.seek(Duration.zero, index: index);
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.rewind,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.fastForward,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: switch (event.processingState) {
        ProcessingState.idle => AudioProcessingState.idle,
        ProcessingState.loading => AudioProcessingState.loading,
        ProcessingState.buffering => AudioProcessingState.buffering,
        ProcessingState.ready => AudioProcessingState.ready,
        ProcessingState.completed => AudioProcessingState.completed,
      },
      playing: playing,
      updatePosition: player.position,
      bufferedPosition: player.bufferedPosition,
      speed: player.speed,
      queueIndex: event.currentIndex,
    ));
  }

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> skipToQueueItem(int index) => jumpToChapter(index);

  @override
  Future<void> stop() async {
    _updateProgress();
    await _savePosition();
    _saveTimer?.cancel();
    await player.pause();
    return super.stop();
  }
}
