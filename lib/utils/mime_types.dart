/// Returns the MIME type associated with an image file name.
String mimeTypeForFileName(String? name) {
  final ext = (name ?? '').split('.').last.toLowerCase();
  if (ext == 'png') return 'image/png';
  if (ext == 'jpg' || ext == 'jpeg') return 'image/jpeg';
  if (ext == 'webp') return 'image/webp';
  if (ext == 'gif') return 'image/gif';
  if (ext == 'svg') return 'image/svg+xml';
  return 'image/png';
}
