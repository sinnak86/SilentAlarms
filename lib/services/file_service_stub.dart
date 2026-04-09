Future<void> downloadJsonFile(String jsonContent, String fileName) async {
  throw UnsupportedError('File download is only supported on web.');
}

Future<String?> pickJsonFile() async {
  throw UnsupportedError('File picker is only supported on web.');
}
