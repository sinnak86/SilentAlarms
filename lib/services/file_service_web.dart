// ignore: avoid_web_libraries_in_flutter
import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Downloads [jsonContent] as a file named [fileName] in the browser.
Future<void> downloadJsonFile(String jsonContent, String fileName) async {
  final blob = html.Blob([jsonContent], 'application/json');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}

/// Opens a file picker restricted to .json files and returns the content string,
/// or null if the user cancelled.
Future<String?> pickJsonFile() async {
  final completer = Completer<String?>();
  final input = html.FileUploadInputElement()..accept = '.json,application/json';
  input.onChange.listen((_) {
    final file = input.files?.first;
    if (file == null) {
      completer.complete(null);
      return;
    }
    final reader = html.FileReader();
    reader.readAsText(file);
    reader.onLoadEnd.listen((_) => completer.complete(reader.result as String?));
    reader.onError.listen((_) => completer.complete(null));
  });
  // If dialog is closed without selection, resolve after a moment
  Future.delayed(const Duration(minutes: 5), () {
    if (!completer.isCompleted) completer.complete(null);
  });
  input.click();
  return completer.future;
}
