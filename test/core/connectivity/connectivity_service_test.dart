import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:libraria/core/connectivity/connectivity_service.dart';

class MockConnectivity extends Mock implements Connectivity {}

void main() {
  // [Régression] `onConnectivityChanged` n'émet que sur un CHANGEMENT de
  // connectivité, jamais l'état courant au moment de l'abonnement. Avant le
  // correctif, `isOnline` restait bloqué à `true` (sa valeur par défaut) si
  // l'app démarrait déjà hors ligne — la bannière hors-ligne (Partie 7) ne se
  // serait alors jamais affichée tant qu'aucun changement de connectivité ne
  // survenait, ce qui peut ne jamais arriver pendant toute une session.
  test('isOnline reflète un démarrage hors-ligne dès la construction, sans attendre un changement', () async {
    final connectivity = MockConnectivity();
    when(() => connectivity.checkConnectivity()).thenAnswer((_) async => [ConnectivityResult.none]);
    when(() => connectivity.onConnectivityChanged)
        .thenAnswer((_) => const Stream<List<ConnectivityResult>>.empty());

    final service = ConnectivityService(connectivity: connectivity);
    addTearDown(service.dispose);

    // checkConnectivity() est asynchrone (Future) — laisser le microtask se résoudre.
    await Future<void>.delayed(Duration.zero);

    expect(service.isOnline, isFalse);
  });

  test('isOnline reste true si l\'app démarre déjà connectée', () async {
    final connectivity = MockConnectivity();
    when(() => connectivity.checkConnectivity()).thenAnswer((_) async => [ConnectivityResult.wifi]);
    when(() => connectivity.onConnectivityChanged)
        .thenAnswer((_) => const Stream<List<ConnectivityResult>>.empty());

    final service = ConnectivityService(connectivity: connectivity);
    addTearDown(service.dispose);
    await Future<void>.delayed(Duration.zero);

    expect(service.isOnline, isTrue);
  });

  test('repasse à true dès qu\'un changement de connectivité redevient en ligne', () async {
    final controller = StreamController<List<ConnectivityResult>>();
    addTearDown(controller.close);
    final connectivity = MockConnectivity();
    when(() => connectivity.checkConnectivity()).thenAnswer((_) async => [ConnectivityResult.none]);
    when(() => connectivity.onConnectivityChanged).thenAnswer((_) => controller.stream);

    final service = ConnectivityService(connectivity: connectivity);
    addTearDown(service.dispose);
    await Future<void>.delayed(Duration.zero);
    expect(service.isOnline, isFalse);

    controller.add([ConnectivityResult.wifi]);
    await Future<void>.delayed(Duration.zero);

    expect(service.isOnline, isTrue);
  });

  // [Régression NF-035] onReconnected() sert à relancer les téléchargements en
  // attente (DownloadManager.resumeQueuedJobs, câblé dans main.dart) — sans ce
  // test, rien ne garantit qu'il est appelé au bon moment (ni trop tôt, ni
  // jamais, ni à chaque changement hors-ligne → hors-ligne qui ne veut rien dire).
  test('onReconnected() est appelé uniquement sur la transition hors-ligne → en ligne', () async {
    final controller = StreamController<List<ConnectivityResult>>();
    addTearDown(controller.close);
    final connectivity = MockConnectivity();
    when(() => connectivity.checkConnectivity()).thenAnswer((_) async => [ConnectivityResult.none]);
    when(() => connectivity.onConnectivityChanged).thenAnswer((_) => controller.stream);

    final service = ConnectivityService(connectivity: connectivity);
    addTearDown(service.dispose);
    var reconnectedCount = 0;
    service.onReconnected = () => reconnectedCount++;
    await Future<void>.delayed(Duration.zero); // état initial hors-ligne posé

    // Toujours hors ligne (un autre type de "none") — ne doit PAS déclencher.
    controller.add([ConnectivityResult.none]);
    await Future<void>.delayed(Duration.zero);
    expect(reconnectedCount, 0);

    // Transition hors-ligne → en ligne — doit déclencher exactement une fois.
    controller.add([ConnectivityResult.wifi]);
    await Future<void>.delayed(Duration.zero);
    expect(reconnectedCount, 1);

    // Reste en ligne (changement wifi → mobile) — ne doit pas re-déclencher.
    controller.add([ConnectivityResult.mobile]);
    await Future<void>.delayed(Duration.zero);
    expect(reconnectedCount, 1);
  });
}
