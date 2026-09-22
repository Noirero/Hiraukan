import 'package:dio/dio.dart';

import 'html_audio_site_source_adapter.dart';
import 'source_html_parser.dart';
import 'unified_source_models.dart';

class Asmr18SourceAdapter extends HtmlAudioSiteSourceAdapter {
  static const String baseUrl = 'https://asmr18.fans';

  Asmr18SourceAdapter({Dio? dio})
      : super(
          kind: UnifiedSourceKind.asmr18,
          baseUrl: baseUrl,
          cacheNamespace: 'asmr18',
          catalogUrlBuilder: _catalogUrl,
          detailUrlMatcher: _isDetailUrl,
          extraPlayableUrlResolver: _resolveHls,
          dio: dio,
        );
}

String _catalogUrl(String keyword, int page) {
  final encoded = Uri.encodeQueryComponent(keyword);
  final prefix = Asmr18SourceAdapter.baseUrl + '/boys/';
  if (keyword.isEmpty) {
    return page <= 1 ? prefix : prefix + 'page/' + page.toString() + '/';
  }
  return page <= 1
      ? prefix + '?s=' + encoded
      : prefix + 'page/' + page.toString() + '/?s=' + encoded;
}

bool _isDetailUrl(Uri uri) {
  final host = uri.host.toLowerCase().replaceFirst('www.', '');
  if (host != 'asmr18.fans') return false;
  return RegExp(
    r'^/(?:boys|girls|all-ages)/rj\d+/?',
    caseSensitive: false,
  ).hasMatch(uri.path);
}

Future<List<String>> _resolveHls(
  String html,
  Uri pageUri,
  String? canonicalId,
  Dio dio,
) async {
  final result = <String>{};
  final normalized = html.replaceAll(r'\/', '/');

  final packed = _unpackPlayerScript(normalized);
  if (packed != null) {
    result.addAll(
      SourceHtmlParser.extractPlayableUrls(packed, base: pageUri),
    );
  }

  final canonical = canonicalId?.toUpperCase();
  if (canonical == null || !canonical.startsWith('RJ')) {
    return result.toList(growable: false);
  }

  final candidates = [
    'https://cdn3.cloudintech.net/file/' + canonical + '/' + canonical + '.m3u8',
    'https://cdn3.cloudintech.net/file/' + canonical + '/1.m3u8',
  ];
  for (final candidate in candidates) {
    if (result.contains(candidate)) continue;
    try {
      final response = await dio.get<String>(
        candidate,
        options: Options(
          responseType: ResponseType.plain,
          headers: {'Referer': Asmr18SourceAdapter.baseUrl + '/'},
          validateStatus: (status) =>
              status != null && status >= 200 && status < 400,
        ),
      );
      final body = response.data ?? '';
      if (body.contains('#EXTM3U')) {
        result.add(candidate);
        break;
      }
    } catch (_) {
      continue;
    }
  }
  return result.toList(growable: false);
}

String? _unpackPlayerScript(String html) {
  final packed = RegExp(
    r'''eval\(function\(p,a,c,k,e,d\)\{.*?\}\((.*?)\)\)''',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(html);
  if (packed == null) return null;
  final args = packed.group(1) ?? '';
  final wordsMatch = RegExp(
    r'''['"]([^'"]+)['"]\.split\(['"]\|['"]\)''',
  ).firstMatch(args);
  final codeMatch = RegExp(r'''^\s*['"]([^'"]*)['"]''').firstMatch(args);
  if (wordsMatch == null || codeMatch == null) return null;

  final words = wordsMatch.group(1)!.split('|');
  var code = codeMatch.group(1)!;
  code = code.replaceAllMapped(RegExp(r'\b([0-9a-z]+)\b'), (match) {
    final token = match.group(1)!;
    final index = int.tryParse(token, radix: 36);
    if (index == null || index < 0 || index >= words.length) return token;
    final replacement = words[index];
    return replacement.isEmpty ? token : replacement;
  });
  return code;
}
