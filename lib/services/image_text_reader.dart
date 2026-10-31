import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Reads the text in the image file at the given path.
typedef TextFromImage = Future<String> Function(String path);

/// Reads text from an image on the phone. The image itself is never uploaded.
/// Returns an empty string when the image has no readable text.
Future<String> readTextFromImageFile(String path) async {
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final recognized = await recognizer.processImage(
      InputImage.fromFilePath(path),
    );
    return recognized.text.trim();
  } finally {
    await recognizer.close();
  }
}

/// Saves pasted image bytes to a temporary file, so they can be read and
/// shown the same way as a picked photo.
Future<String> saveTempImage(Uint8List bytes) async {
  final name = 'phishnet_paste_${DateTime.now().microsecondsSinceEpoch}.png';
  final file = File('${Directory.systemTemp.path}/$name');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
