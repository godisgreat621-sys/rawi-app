// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';
import 'dart:typed_data';

Future<Uint8List?> pickImageForWeb() async {
  final completer = Completer<Uint8List?>();
  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..click();

  input.onChange.listen((e) {
    final files = input.files;
    if (files == null || files.isEmpty) {
      completer.complete(null);
      return;
    }
    final reader = html.FileReader();
    reader.readAsArrayBuffer(files[0]);
    reader.onLoad.listen((_) {
      final result = reader.result;
      if (result is Uint8List) {
        completer.complete(result);
      } else {
        completer.complete(
            Uint8List.view((result as dynamic).buffer as ByteBuffer));
      }
    });
    reader.onError.listen((_) {
      completer.completeError(Exception('فشل قراءة الصورة'));
    });
  });

  return completer.future;
}
