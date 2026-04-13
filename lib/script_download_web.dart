// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:convert';
import 'dart:html' as html;

import 'script_download_models.dart';

Future<DownloadResult> saveScriptFile({
  required String filename,
  required String content,
}) async {
  final encoded = base64Encode(utf8.encode(content));
  final anchor = html.AnchorElement(
    href: 'data:text/plain;charset=utf-8;base64,$encoded',
  )
    ..download = filename
    ..style.display = 'none';

  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();

  return DownloadResult(
    message:
        '\u8173\u672c\u6a94\u6848\u5df2\u958b\u59cb\u4e0b\u8f09: $filename',
  );
}
