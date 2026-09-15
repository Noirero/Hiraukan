import 'dart:convert';

class SourceHtmlParser {
  static final RegExp _rjPattern = RegExp(
    r'\b(?:RJ|BJ|VJ)0*\d{5,10}\b',
    caseSensitive: false,
  );

  static String? extractCanonicalId(String? text) {
    if (text == null) return null;
    final match = _rjPattern.firstMatch(text);
    if (match == null) return null;
    final raw = match.group(0)!.toUpperCase();
    final prefix = raw.substring(0, 2);
    final digits = raw.substring(2).replaceFirst(RegExp(r'^0+(?=\d)'), '');
    return '$prefix$digits';
  }

  static String stripTags(String input) {
    final withoutScripts = input
        .replaceAll(
          RegExp(
            r'<script\b[^>]*>.*?</script>',
            caseSensitive: false,
            dotAll: true,
          ),
          ' ',
        )
        .replaceAll(
          RegExp(
            r'<style\b[^>]*>.*?</style>',
            caseSensitive: false,
            dotAll: true,
          ),
          ' ',
        );
    return decodeEntities(
      withoutScripts.replaceAll(RegExp(r'<[^>]+>'), ' '),
    ).replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String decodeEntities(String input) {
    var value = input
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(r'\/', '/');

    value = value.replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
      final code = int.tryParse(match.group(1)!);
      return code == null ? match.group(0)! : String.fromCharCode(code);
    });
    value = value.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (match) {
      final code = int.tryParse(match.group(1)!, radix: 16);
      return code == null ? match.group(0)! : String.fromCharCode(code);
    });
    return value;
  }

  static String? extractMetaContent(String html, String key) {
    final escaped = RegExp.escape(key);
    final patterns = [
      RegExp(
        '<meta[^>]+(?:property|name)=["\']$escaped["\'][^>]+content=["\']([^"\']+)["\']',
        caseSensitive: false,
      ),
      RegExp(
        '<meta[^>]+content=["\']([^"\']+)["\'][^>]+(?:property|name)=["\']$escaped["\']',
        caseSensitive: false,
      ),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      if (match != null) return decodeEntities(match.group(1)!.trim());
    }
    return null;
  }

  static String? extractTitle(String html) {
    final ogTitle = extractMetaContent(html, 'og:title');
    if (ogTitle != null && ogTitle.isNotEmpty) return ogTitle;

    for (final tag in ['h1', 'title']) {
      final match = RegExp(
        '<$tag\\b[^>]*>(.*?)</$tag>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(html);
      if (match != null) {
        final value = stripTags(match.group(1)!);
        if (value.isNotEmpty) return value;
      }
    }
    return null;
  }

  static String? extractFirstImage(String html, {Uri? base}) {
    final meta = extractMetaContent(html, 'og:image');
    if (meta != null && meta.isNotEmpty) return resolveUrl(meta, base: base);

    final match = RegExp(
      r'''<img\b[^>]+(?:src|data-src)=["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(html);
    if (match == null) return null;
    return resolveUrl(match.group(1)!, base: base);
  }

  static List<String> extractAudioUrls(String html, {Uri? base}) {
    final normalized = html.replaceAll(r'\/', '/');
    final urls = <String>{};
    final patterns = <RegExp>[
      RegExp(
        r'''(?:src|href|file|url)\s*[:=]\s*["']([^"']+\.(?:mp3|m4a|aac|ogg|opus|wav|flac)(?:\?[^"']*)?)["']''',
        caseSensitive: false,
      ),
      RegExp(
        r'''(https?://[^\s"'<>]+\.(?:mp3|m4a|aac|ogg|opus|wav|flac)(?:\?[^\s"'<>]*)?)''',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      for (final match in pattern.allMatches(normalized)) {
        final raw = decodeEntities(match.group(1)!);
        final resolved = resolveUrl(raw, base: base);
        if (resolved != null &&
            (resolved.startsWith('http://') || resolved.startsWith('https://'))) {
          urls.add(resolved);
        }
      }
    }
    return urls.toList(growable: false);
  }

  static String? resolveUrl(String? raw, {Uri? base}) {
    if (raw == null) return null;
    final value = decodeEntities(raw.trim());
    if (value.isEmpty ||
        value.startsWith('data:') ||
        value.startsWith('javascript:')) {
      return null;
    }
    final uri = Uri.tryParse(value);
    if (uri == null) return null;
    if (uri.hasScheme) return uri.toString();
    if (base == null) return value;
    return base.resolveUri(uri).toString();
  }

  static int? parseDurationSeconds(String? text) {
    if (text == null) return null;
    final match =
        RegExp(r'\b(?:(\d{1,2}):)?(\d{1,2}):(\d{2})\b').firstMatch(text);
    if (match == null) return null;
    final hours = int.tryParse(match.group(1) ?? '0') ?? 0;
    final minutes = int.tryParse(match.group(2) ?? '0') ?? 0;
    final seconds = int.tryParse(match.group(3) ?? '0') ?? 0;
    return hours * 3600 + minutes * 60 + seconds;
  }

  static int stableNegativeId(String value) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(value)) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    if (hash == 0) hash = 1;
    return -hash;
  }

  static String basenameFromUrl(String url, int index) {
    final uri = Uri.tryParse(url);
    final segments =
        uri?.pathSegments.where((segment) => segment.isNotEmpty).toList() ??
            const [];
    final raw = segments.isEmpty ? 'Track ${index + 1}' : segments.last;
    try {
      return Uri.decodeComponent(raw);
    } catch (_) {
      return raw;
    }
  }
}
