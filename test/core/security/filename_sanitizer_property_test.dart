import 'package:flutter_test/flutter_test.dart';

import 'package:libraria/core/security/filename_sanitizer.dart';

void main() {
  test('FilenameSanitizer: ne produit jamais ".." et caractères interdits + longueur <= 100', () {
    const samples = [
      '.../..',
      '../..',
      'a<b>c',
      'a:"b',
      'a|b',
      'a?b',
      'a*b',
      'a\\b',
      'a\nb',
      'CON',
      '   ',
      'a..b',
      'file.txt',
      'a:b',
    ];

    for (final input in samples) {
      final out = FilenameSanitizer.sanitize(input);

      expect(out.contains('..'), isFalse, reason: 'input=$input out=$out');
      expect(RegExp(r'[<>:"/\\|?*\x00-\x1f]').hasMatch(out), isFalse,
          reason: 'input=$input out=$out');
      expect(out.length <= 100, isTrue, reason: 'input=$input out=$out');
    }
  });
}

