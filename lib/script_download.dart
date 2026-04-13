import 'script_download_models.dart';
import 'script_download_stub.dart'
    if (dart.library.html) 'script_download_web.dart'
    if (dart.library.io) 'script_download_io.dart';

Future<DownloadResult> downloadScriptFile({
  required String filename,
  required String content,
}) {
  return saveScriptFile(
    filename: filename,
    content: content,
  );
}
