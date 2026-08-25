import 'dart:typed_data';
import 'package:gal/gal.dart';

Future<String?> saveFilePlatform(Uint8List bytes, String filename) async {
  await Gal.putImageBytes(bytes, name: filename);
  return filename;
}
