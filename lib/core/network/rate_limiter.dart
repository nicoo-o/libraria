import 'dart:collection';

class RateLimiter {
  final int maxPerWindow;
  final Duration window;
  final _calls = <String, Queue<DateTime>>{};

  RateLimiter({this.maxPerWindow = 30, this.window = const Duration(seconds: 60)});

  Future<void> acquire(String sourceId) async {
    final now = DateTime.now();
    final queue = _calls.putIfAbsent(sourceId, () => Queue());
    while (queue.isNotEmpty && now.difference(queue.first) > window) {
      queue.removeFirst();
    }
    if (queue.length >= maxPerWindow) {
      final waitMs = window.inMilliseconds - now.difference(queue.first).inMilliseconds;
      if (waitMs > 0) await Future.delayed(Duration(milliseconds: waitMs));
    }
    queue.add(DateTime.now());
  }
}
