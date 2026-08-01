import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../core/models/library_item.dart';
import '../l10n/app_localizations.dart';
import '../library/library_repository.dart';
import 'audiobook_handler.dart';

/// [Correctif i18n] `_loadError` ne stocke plus directement une chaîne
/// traduite : le chargement tourne depuis `didChangeDependencies()`, où le
/// choix du texte localisé doit être différé à `build()` — voir plus bas.
enum _LoadFailureReason { noLocalFile, noAudioFiles, other }

/// Vitesses proposées au cycle (bouton unique, pas de menu — cohérent avec
/// le reste de l'écran qui n'utilise que des IconButton).
const _speedSteps = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

/// Lecteur audiobook — `just_audio` via `AudiobookHandler` (`audio_service`) :
/// lecture multi-fichiers en continu, retour/avance 30s, sauvegarde de
/// position toutes les 10s, vitesse par livre (NF-023), navigation par
/// chapitre, lecture en ARRIÈRE-PLAN avec notification/lockscreen
/// (07_READER_AUDIOBOOK.md ; trous comblés listés dans l'audit V1).
///
/// [Décision d'architecture — trou comblé] Ce widget ne possède plus son
/// propre `AudioPlayer()` : il lit `context.read<AudiobookHandler>()`, un
/// singleton créé une seule fois dans `main()` et qui survit à la fermeture
/// de cet écran. C'est ce qui permet à la lecture de continuer quand l'écran
/// s'éteint ou que l'utilisateur revient à l'accueil — auparavant,
/// `_player.dispose()` dans `dispose()` tuait la lecture dès qu'on quittait
/// l'écran, et `audio_service` restait une dépendance jamais importée nulle
/// part (voir audit). La sauvegarde de position et le chargement des
/// fichiers ont été déplacés dans `AudiobookHandler` pour la même raison :
/// ils doivent survivre à ce widget.
///
/// Position stockée dans `last_cfi` comme `"<index fichier>:<position ms>"`,
/// PAS une seule valeur en secondes — sinon la reprise pointe vers le mauvais
/// chapitre après fermeture/réouverture d'un livre LibriVox multi-fichiers
/// (dizaines de MP3 séparés, ordre alphabétique = ordre des chapitres).
class AudioPlayerScreen extends StatefulWidget {
  const AudioPlayerScreen({super.key, required this.item});
  final LibraryItem item;

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  bool _ready = false;
  _LoadFailureReason? _loadError;

  late final LibraryRepository _libraryRepository;
  late final AudiobookHandler _handler;
  bool _dependenciesReady = false;

  AudioPlayer get _player => _handler.player;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // [Correctif] Capturé ici, pas dans initState() : AudiobookHandler est
    // fourni via Provider (InheritedWidget), pas disponible avant que le
    // widget soit attaché à l'arbre.
    if (!_dependenciesReady) {
      _libraryRepository = context.read<LibraryRepository>();
      _handler = context.read<AudiobookHandler>();
      _dependenciesReady = true;
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    try {
      await _handler.loadItem(widget.item, _libraryRepository);
      if (mounted) setState(() => _ready = true);
    } on StateError catch (e) {
      if (!mounted) return;
      setState(() => _loadError = switch (e.message) {
            'noLocalFile' => _LoadFailureReason.noLocalFile,
            'noAudioFiles' => _LoadFailureReason.noAudioFiles,
            _ => _LoadFailureReason.other,
          });
    } catch (_) {
      if (mounted) setState(() => _loadError = _LoadFailureReason.other);
    }
  }

  Future<void> _seekRelative(Duration delta) async {
    final target = _player.position + delta;
    final duration = _player.duration ?? Duration.zero;
    if (target < Duration.zero) {
      await _player.seek(Duration.zero);
    } else if (duration > Duration.zero && target > duration) {
      await _player.seek(duration);
    } else {
      await _player.seek(target);
    }
  }

  /// Vitesse de lecture (NF-023) — cycle simple sur `_speedSteps`, persisté
  /// PAR LIVRE via `AudiobookHandler.setPlaybackSpeed` (colonne
  /// `playback_speed_pref`, squelette mort jusqu'ici — voir audit).
  Future<void> _cycleSpeed(double current) async {
    final idx = _speedSteps.indexWhere((s) => (s - current).abs() < 0.01);
    final next = _speedSteps[(idx < 0 ? 0 : idx + 1) % _speedSteps.length];
    await _handler.setPlaybackSpeed(next);
  }

  String _formatSpeed(double speed) {
    // 1.0 -> "1×", 1.25 -> "1.25×" -- pas de zéro superflu.
    final s = speed == speed.roundToDouble() ? speed.toStringAsFixed(0) : speed.toString();
    return '$s×';
  }

  String _chapterLabel(int index) => p.basenameWithoutExtension(_handler.chapterFiles[index].path);

  /// Navigation par chapitre (trou comblé — audit V1 : "aucune UI de
  /// navigation par chapitre"). Un "chapitre" ici = un fichier MP3 de la
  /// séquence LibriVox ; pas de lecture de métadonnées ID3 (pas de package
  /// dédié dans le budget de fonctionnalités actuel — R1'' chapitre 12), le
  /// libellé retombe donc sur le nom de fichier, déjà l'ordre de lecture réel.
  Future<void> _showChapters() async {
    final l10n = AppLocalizations.of(context);
    final files = _handler.chapterFiles;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return StreamBuilder<int?>(
          stream: _player.currentIndexStream,
          initialData: _player.currentIndex,
          builder: (context, snapshot) {
            final currentIndex = snapshot.data ?? 0;
            return ListView(
              shrinkWrap: true,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l10n.audioChaptersTitle, style: Theme.of(context).textTheme.titleMedium),
                ),
                for (var i = 0; i < files.length; i++)
                  ListTile(
                    leading: Icon(i == currentIndex ? Icons.play_arrow : Icons.menu_book_outlined),
                    title: Text(l10n.audioChapterNumber(i + 1)),
                    subtitle: Text(_chapterLabel(i), overflow: TextOverflow.ellipsis),
                    selected: i == currentIndex,
                    onTap: () async {
                      await _handler.jumpToChapter(i);
                      if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                    },
                  ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_loadError != null) {
      // [Correctif i18n] Traduction choisie ici, pas dans _load() — voir le
      // commentaire sur _LoadFailureReason plus haut.
      final message = switch (_loadError!) {
        _LoadFailureReason.noLocalFile => l10n.readerNoLocalFile,
        _LoadFailureReason.noAudioFiles => l10n.audioNoFilesFound,
        _LoadFailureReason.other => l10n.audioLoadErrorGeneric,
      };
      return Scaffold(
        appBar: AppBar(title: Text(widget.item.title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(message, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    if (!_ready) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.item.title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final hasChapters = _handler.chapterFiles.length > 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item.title, overflow: TextOverflow.ellipsis),
        actions: [
          StreamBuilder<double>(
            stream: _player.speedStream,
            initialData: _player.speed,
            builder: (context, snapshot) {
              final speed = snapshot.data ?? 1.0;
              return TextButton(
                onPressed: () => _cycleSpeed(speed),
                child: Text(_formatSpeed(speed)),
              );
            },
          ),
          if (hasChapters)
            IconButton(
              icon: const Icon(Icons.menu),
              tooltip: l10n.audioChaptersTitle,
              onPressed: _showChapters,
            ),
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          StreamBuilder<Duration>(
            stream: _player.positionStream,
            builder: (context, snapshot) {
              final position = snapshot.data ?? Duration.zero;
              final duration = _player.duration ?? Duration.zero;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Slider(
                      value: duration.inMilliseconds > 0
                          ? position.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble()
                          : 0.0,
                      max: duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : 1.0,
                      onChanged: duration.inMilliseconds > 0
                          ? (v) => _player.seek(Duration(milliseconds: v.round()))
                          : null,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatDuration(position)),
                        Text(_formatDuration(duration)),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 40,
                icon: const Icon(Icons.replay_30),
                tooltip: l10n.audioRewind30,
                onPressed: () => _seekRelative(const Duration(seconds: -30)),
              ),
              const SizedBox(width: 24),
              StreamBuilder<PlayerState>(
                stream: _player.playerStateStream,
                builder: (context, snapshot) {
                  final playing = snapshot.data?.playing ?? false;
                  // [Correctif audit U-03] Aucun tooltip sur les contrôles
                  // icône-only : TalkBack/Narrator ne pouvait rien annoncer.
                  return IconButton(
                    iconSize: 72,
                    icon: Icon(playing ? Icons.pause_circle : Icons.play_circle),
                    tooltip: playing ? l10n.pause : l10n.audioPlay,
                    onPressed: () => playing ? _player.pause() : _player.play(),
                  );
                },
              ),
              const SizedBox(width: 24),
              IconButton(
                iconSize: 40,
                icon: const Icon(Icons.forward_30),
                tooltip: l10n.audioForward30,
                onPressed: () => _seekRelative(const Duration(seconds: 30)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // [Info persistante] Rappel que la lecture continue en arrière-plan
          // (notification + lockscreen) — évite qu'un utilisateur ferme
          // l'écran en croyant, comme avant ce correctif, que ça coupe le son.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              l10n.audioBackgroundHint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  // [Correctif — trou comblé] PAS de dispose() du player ici : le player
  // appartient à AudiobookHandler (singleton), pas à cet écran. Le disposer
  // ici tuerait la lecture dès que l'utilisateur quitte cet écran, ce qui
  // est exactement le bug que ce correctif élimine (lecture en arrière-plan).
  // La sauvegarde périodique de position vit désormais dans le handler et
  // continue de tourner tant que la lecture est active, indépendamment de
  // ce widget.
}
