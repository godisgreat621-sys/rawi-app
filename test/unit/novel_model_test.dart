import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_app/core/image_utils.dart';

// اختبارات بسيطة على دوال لا تعتمد على Firebase
void main() {
  group('optimizeImageUrl — حالات الحافة', () {
    test('رابط بدون cloudinary يُعاد كما هو', () {
      const url = 'https://storage.googleapis.com/bucket/image.jpg';
      expect(optimizeImageUrl(url), equals(url));
    });

    test('null يُعيد سلسلة فارغة', () {
      expect(optimizeImageUrl(null), '');
    });

    test('رابط فارغ يُعيد فارغاً', () {
      expect(optimizeImageUrl(''), '');
    });

    test('لا يُكرر f_auto إذا كانت موجودة', () {
      const url =
          'https://res.cloudinary.com/x/image/upload/f_auto,q_auto,w_800/v1/img.jpg';
      expect(optimizeImageUrl(url), url);
    });

    test('يُدرج تحويلات بعد /upload/', () {
      const url =
          'https://res.cloudinary.com/x/image/upload/v123/rawi/img.jpg';
      final out = optimizeImageUrl(url, width: 600);
      expect(out,
          'https://res.cloudinary.com/x/image/upload/f_auto,q_auto,w_600/v123/rawi/img.jpg');
    });
  });
}
