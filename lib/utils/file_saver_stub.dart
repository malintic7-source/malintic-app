import 'dart:typed_data';

Future<String?> saveFilePlatform(Uint8List bytes, String filename) async {
  throw UnsupportedError(
    "L'enregistrement de fichiers n'est pas pris en charge sur cette plateforme.",
  );
}
