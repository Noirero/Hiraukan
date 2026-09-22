import 'package:dio/dio.dart';

import 'html_audio_site_source_adapter.dart';
import 'unified_source_models.dart';

class JapaneseAsmrSourceAdapter extends HtmlAudioSiteSourceAdapter {
  static const String baseUrl = 'https://japaneseasmr.com';

  JapaneseAsmrSourceAdapter({Dio? dio})
      : super(
          kind: UnifiedSourceKind.japaneseAsmr,
          baseUrl: baseUrl,
          cacheNamespace: 'japaneseasmr',
          catalogUrlBuilder: _catalogUrl,
          detailUrlMatcher: _isDetailUrl,
          dio: dio,
        );
}

String _catalogUrl(String keyword, int page) {
  final encoded = Uri.encodeQueryComponent(keyword);
  if (keyword.isEmpty) {
    return page <= 1 ? JapaneseAsmrSourceAdapter.baseUrl + '/' : JapaneseAsmrSourceAdapter.baseUrl + '/page/' + page.toString() + '/';
  }
  return page <= 1
      ? JapaneseAsmrSourceAdapter.baseUrl + '/?s=' + encoded
      : JapaneseAsmrSourceAdapter.baseUrl + '/page/' + page.toString() + '/?s=' + encoded;
}

bool _isDetailUrl(Uri uri) {
  final host = uri.host.toLowerCase().replaceFirst('www.', '');
  if (host != 'japaneseasmr.com') return false;
  return RegExp(r'^/\d+/?$').hasMatch(uri.path);
}
