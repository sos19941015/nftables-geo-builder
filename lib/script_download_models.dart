class DownloadResult {
  const DownloadResult({
    required this.message,
    this.savedPath,
  });

  final String message;
  final String? savedPath;
}
