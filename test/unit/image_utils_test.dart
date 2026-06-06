import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_app/core/image_utils.dart';

void main() {
  group('optimizeImageUrl', () {
    const base = 'https://res.cloudinary.com/dkwnjmbzl/image/upload';

    test('يُضيف تحويلات للرابط العادي', () {
      const url = '$base/v1234/rawi/covers/img.jpg';
      final result = optimizeImageUrl(url);
      expect(result, contains('f_auto,q_auto,w_800'));
      expect(result, startsWith(base));
    });

    test('يحترم العرض المخصص', () {
      const url = '$base/v1234/img.jpg';
      final result = optimizeImageUrl(url, width: 400);
      expect(result, contains('w_400'));
    });

    test('لا يُكرر التحويلات إذا كانت موجودة', () {
      const url = '$base/f_auto,q_auto,w_800/v1234/img.jpg';
      expect(optimizeImageUrl(url), equals(url));
    });

    test('يُعيد رابطاً فارغاً للمدخل الفارغ', () {
      expect(optimizeImageUrl(null), isEmpty);
      expect(optimizeImageUrl(''), isEmpty);
    });

    test('يُعيد الرابط كما هو إذا لم يحتوِ /upload/', () {
      const url = 'https://example.com/image.jpg';
      expect(optimizeImageUrl(url), equals(url));
    });
  });
}
