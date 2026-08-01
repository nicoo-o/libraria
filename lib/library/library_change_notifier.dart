import 'package:flutter/foundation.dart';

/// Signal partage, minimal, pour prevenir LibraryScreen qu'un changement
/// externe (restauration depuis la Corbeille, import en masse futur, etc.)
/// necessite un rafraichissement -- meme pattern que l'observation de
/// DownloadManager deja en place dans LibraryScreen, pour un cas que
/// DownloadManager ne couvre pas.
class LibraryChangeNotifier extends ChangeNotifier {
  int _version = 0;
  int get version => _version;

  void notifyChanged() {
    _version++;
    notifyListeners();
  }
}