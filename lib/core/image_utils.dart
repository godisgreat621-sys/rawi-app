// يُضيف تحويلات Cloudinary تلقائياً لتقليص حجم الصورة
// .../upload/v123/path.jpg → .../upload/f_auto,q_auto,w_N/v123/path.jpg
String optimizeImageUrl(String? url, {int width = 800}) {
  if (url == null || url.isEmpty) return '';
  const marker = '/upload/';
  final idx = url.indexOf(marker);
  if (idx == -1) return url;
  final after = url.substring(idx + marker.length);
  if (after.startsWith('f_auto') || after.startsWith('q_auto')) return url;
  return '${url.substring(0, idx)}${marker}f_auto,q_auto,w_$width/$after';
}
