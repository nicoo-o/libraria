import 'package:flutter_test/flutter_test.dart';
import 'package:libraria/core/network/rate_limiter.dart';

void main() {
  test('RateLimiter laisse passer jusqu\'à maxPerWindow appels sans délai', () async {
    final limiter = RateLimiter(maxPerWindow: 3, window: const Duration(seconds: 60));
    final stopwatch = Stopwatch()..start();
    for (var i = 0; i < 3; i++) {
      await limiter.acquire('test-source');
    }
    stopwatch.stop();
    expect(stopwatch.elapsedMilliseconds < 500, isTrue);
  });
}
