Map<String, String>? sourceImageHeadersFor(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return null;

  final host = uri.host.toLowerCase();
  if (host == 'pic.weeabo0.xyz' ||
      host == 'img.weeabo0.xyz' ||
      host == 'pic1.weeabo0.xyz') {
    return const <String, String>{
      'Referer': 'https://japaneseasmr.com/',
      'Origin': 'https://japaneseasmr.com',
      'User-Agent': 'Hiraukan/3.8 UnifiedSources',
    };
  }
  return null;
}
