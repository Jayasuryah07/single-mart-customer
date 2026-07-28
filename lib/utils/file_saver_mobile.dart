import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Mobile/native implementation: saves the bytes to device storage.
Future<String> saveAndDownloadFile(List<int> bytes, String fileName) async {
  Directory? directory;
  if (Platform.isAndroid) {
    directory = await getExternalStorageDirectory();
  }
  directory ??= await getApplicationDocumentsDirectory();

  final parentDir = Directory(directory.path);
  if (!await parentDir.exists()) {
    await parentDir.create(recursive: true);
  }

  final filePath = '${directory.path}/$fileName';
  final file = File(filePath);
  await file.writeAsBytes(bytes);
  return filePath;
}
