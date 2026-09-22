import 'package:dio/dio.dart';

import 'html_audio_site_source_adapter.dart';
import 'unified_source_models.dart';

class AsmrHentaiNetSourceAdapter extends HtmlAudioSiteSourceAdapter {
  static const String baseUrl = 'https://asmrhentai.net';

  AsmrHentaiNetSourceAdapter({Dio? dio})
      : super(
          kind: UnifiedSourceKind.asmrHentaiNet,
          baseUrl: baseUrl,
          cacheNamespace: 'asmrhentai-net',
          catalogUrlBuilder: _catalogUrl,
          detailUrlMatcher: _isDetailUrl,
          mediaEnabled: false,
          dio: dio,
        );
}

String _catalogUrl(String keyword, int page) {
  final encoded = Uri.encodeQueryComponent(keyword);
  if (keyword.isEmpty) {
    return page <= 1 ? AsmrHentaiNetSourceAdapter.baseUrl + '/' : AsmrHentaiNetSourceAdapter.baseUrl + '/page/' + page.toString() + '/';
  }
  return page <= 1
      ? AsmrHentaiNetSourceAdapter.baseUrl + '/?s=' + encoded
      : AsmrHentaiNetSourceAdapter.baseUrl + '/page/' + page.toString() + '/?s=' + encoded;
}

bool _isDetailUrl(Uri uri) {
  final host = uri.host.toLowerCase().replaceFirst('www.', '');
  if (host != 'asmrhentai.net') return false;
  return RegExp(r'^/RJ\d+/', caseSensitive: false).hasMatch(uri.path);
}
