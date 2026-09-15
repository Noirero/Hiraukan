import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/sources/source_html_parser.dart';

void main() {
  group('SourceHtmlParser', () {
    test('normalizes canonical DLsite ids for matching', () {
      expect(SourceHtmlParser.extractCanonicalId('Work RJ01655238'), 'RJ1655238');
      expect(SourceHtmlParser.extractCanonicalId('bj00012345'), 'BJ12345');
      expect(SourceHtmlParser.extractCanonicalId('nothing here'), isNull);
    });

    test('strips markup and decodes basic entities', () {
      const html = '<h1>Rain &amp; Night</h1><script>ignore()</script>';
      expect(SourceHtmlParser.stripTags(html), 'Rain & Night');
    });

    test('extracts meta content regardless of quote style', () {
      const html = '''
        <meta property="og:title" content="Rainy Night Study">
        <meta content='https://cdn.example/cover.jpg' property='og:image'>
      ''';
      expect(SourceHtmlParser.extractTitle(html), 'Rainy Night Study');
      expect(
        SourceHtmlParser.extractFirstImage(
          html,
          base: Uri.parse('https://example.test/work/'),
        ),
        'https://cdn.example/cover.jpg',
      );
    });

    test('resolves relative and absolute audio urls without duplicates', () {
      const html = '''
        <audio src="/audio/01.mp3"></audio>
        <a href='https://cdn.example/02.m4a?token=abc'>two</a>
        <script>const file = "/audio/01.mp3";</script>
      ''';
      final urls = SourceHtmlParser.extractAudioUrls(
        html,
        base: Uri.parse('https://example.test/work/123'),
      );
      expect(urls, contains('https://example.test/audio/01.mp3'));
      expect(urls, contains('https://cdn.example/02.m4a?token=abc'));
      expect(urls.toSet().length, urls.length);
    });

    test('parses durations and stable ids', () {
      expect(SourceHtmlParser.parseDurationSeconds('duration 1:02:03'), 3723);
      expect(SourceHtmlParser.parseDurationSeconds('42:18'), 2538);
      final first = SourceHtmlParser.stableNegativeId('source:RJ123456');
      final second = SourceHtmlParser.stableNegativeId('source:RJ123456');
      expect(first, lessThan(0));
      expect(first, second);
    });
  });
}
