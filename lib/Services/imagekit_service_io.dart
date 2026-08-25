import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:gestion_formations/utils/mime_types.dart';

class ImageKitService {
  Future<String?> pickAndUploadImage({String folder = 'formations'}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return null;

      final platformFile = result.files.first;
      if (platformFile.bytes != null) {
        return await uploadImageFromBytes(platformFile.bytes!, folder: folder, fileName: platformFile.name);
      }
      if (platformFile.path != null) {
        final file = File(platformFile.path!);
        if (file.existsSync()) {
          return await uploadImage(file, folder: folder);
        }
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<String?> uploadImageFromBytes(
    List<int> bytes, {
    String folder = 'formations',
    String? fileName,
  }) async {
    final mime = mimeTypeForFileName(fileName);
    final base64Str = base64Encode(bytes);
    return 'data:$mime;base64,$base64Str';
  }

  Future<String?> uploadImage(File file, {String folder = 'formations'}) async {
    final fileBytes = await file.readAsBytes();
    return await uploadImageFromBytes(fileBytes, folder: folder, fileName: file.uri.pathSegments.last);
  }
}
