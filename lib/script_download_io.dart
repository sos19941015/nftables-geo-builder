import 'dart:io';

import 'script_download_models.dart';

Future<DownloadResult> saveScriptFile({
  required String filename,
  required String content,
}) async {
  final directory = _resolveDownloadDirectory();
  await directory.create(recursive: true);

  final file = File('${directory.path}${Platform.pathSeparator}$filename');
  await file.writeAsString(content);

  return DownloadResult(
    message: '\u8173\u672c\u5df2\u5132\u5b58\u81f3 ${file.path}',
    savedPath: file.path,
  );
}

Directory _resolveDownloadDirectory() {
  final home = Platform.environment['USERPROFILE'] ??
      Platform.environment['HOME'] ??
      Directory.current.path;
  final downloadPath = '$home${Platform.pathSeparator}Downloads';
  return Directory(downloadPath);
}
