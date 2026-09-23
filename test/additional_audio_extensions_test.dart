import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/extensions/asmr18_audio_extension.dart';
import 'package:kikoeru_flutter/src/extensions/asmr_hentai_net_audio_extension.dart';
import 'package:kikoeru_flutter/src/extensions/audio_extension_manifest.dart';
import 'package:kikoeru_flutter/src/extensions/japanese_asmr_audio_extension.dart';
import 'package:kikoeru_flutter/src/models/audio_track.dart';
import 'package:kikoeru_flutter/src/services/source_subtitle_service.dart';
import 'package:kikoeru_flutter/src/sources/asmr18_source_adapter.dart';
import 'package:kikoeru_flutter/src/sources/asmr_hentai_net_source_adapter.dart';
import 'package:kikoeru_flutter/src/sources/japanese_asmr_source_adapter.dart';
import 'package:kikoeru_flutter/src/sources/source_html_parser.dart';
import 'package:kikoeru_flutter/src/utils/source_request_headers.dart';

void main() {
  test('additional audio extensions expose conservative capabilities', () {
    final japanese = createJapaneseAsmrAudioExtension().manifest;
    final asmr18 = createAsmr18AudioExtension().manifest;
    final hentaiNet = createAsmrHentaiNetAudioExtension().manifest;

    expect(japanese.id, 'miyorare.audio.japanese_asmr');
    expect(japanese.capabilities, contains(AudioExtensionCapability.playback));
    expect(japanese.capabilities, contains(AudioExtensionCapability.download));

    expect(asmr18.id, 'miyorare.audio.asmr18');
    expect(asmr18.capabilities, contains(AudioExtensionCapability.playback));
    expect(asmr18.capabilities, isNot(contains(AudioExtensionCapability.download)));

    expect(hentaiNet.id, 'miyorare.audio.asmr_hentai_net');
    expect(hentaiNet.capabilities, contains(AudioExtensionCapability.detail));
    expect(hentaiNet.capabilities, contains(AudioExtensionCapability.playback));
    expect(hentaiNet.capabilities, contains(AudioExtensionCapability.subtitles));
    expect(
      hentaiNet.capabilities,
      isNot(contains(AudioExtensionCapability.download)),
    );
  });

  test('playable URL parser keeps direct audio and HLS without duplicates', () {
    const html = '''
      <audio src="/audio/track.m4a"></audio>
      <video><source src="https://cdn.example.test/work/main.m3u8"></video>
      <script>var backup = "https://cdn.example.test/work/main.m3u8";</script>
    ''';

    final urls = SourceHtmlParser.extractPlayableUrls(
      html,
      base: Uri.parse('https://example.test/work/'),
    );

    expect(urls, contains('https://example.test/audio/track.m4a'));
    expect(urls, contains('https://cdn.example.test/work/main.m3u8'));
    expect(
      urls.where((url) => url == 'https://cdn.example.test/work/main.m3u8'),
      hasLength(1),
    );
  });

  test('cover extraction prefers the media poster over a site-wide og image', () {
    const html = '''
      <meta property="og:image" content="/site-default.jpg">
      <video poster="/work-cover.jpg"></video>
    ''';
    expect(
      SourceHtmlParser.extractFirstImage(
        html,
        base: Uri.parse('https://example.test/work/1'),
      ),
      'https://example.test/work-cover.jpg',
    );
  });

  test('JapaneseASMR parser reads real chapter-style metadata', () {
    const html = '''
      <html>
        <head>
          <meta property="og:title" content="Chapter Work – Japanese ASMR">
          <meta property="og:image" content="/cover.jpg">
        </head>
        <body>
          <p>[260913][Another] Chapter Work [RJ01717942]</p>
          <p>CV: Kosuzu Momoka, Second Voice</p>
          <div>Player 1</div>
          <iframe src="/embed/player-one"></iframe>
          <table>
            <tr><td>00:00:00</td><td>track1_First</td></tr>
            <tr><td>00:04:18</td><td>track2_Second</td></tr>
            <tr><td>00:11:23</td><td>track3_Third</td></tr>
          </table>
          <p>総再生時間: 1時間19分38秒</p>
          <a href="/tag/ear-cleaning/">Ear Cleaning</a>
          <div>Video Ads</div>
          <iframe src="https://ads.example.test/video-player"></iframe>
        </body>
      </html>
    ''';

    expect(JapaneseAsmrPageParser.canonicalId(html), 'RJ01717942');
    expect(
      JapaneseAsmrPageParser.title(
        html,
        canonical: 'RJ01717942',
      ),
      'Chapter Work',
    );
    expect(JapaneseAsmrPageParser.circle(html), 'Another');
    expect(JapaneseAsmrPageParser.releaseDate(html), '2026-09-13');
    expect(
      JapaneseAsmrPageParser.voiceActors(html),
      ['Kosuzu Momoka', 'Second Voice'],
    );
    expect(JapaneseAsmrPageParser.tags(html), contains('Ear Cleaning'));
    expect(JapaneseAsmrPageParser.totalDurationSeconds(html), 4778);

    final chapters = JapaneseAsmrPageParser.chapters(
      html,
      totalDurationSeconds: 4778,
    );
    expect(chapters, hasLength(3));
    expect(chapters[0].startSeconds, 0);
    expect(chapters[0].endSeconds, 258);
    expect(chapters[1].startSeconds, 258);
    expect(chapters[1].endSeconds, 683);
    expect(chapters[1].durationSeconds, 425);
    expect(chapters[2].endSeconds, 4778);

    expect(
      JapaneseAsmrPageParser.embeddedPlayerUrls(
        html,
        Uri.parse('https://japaneseasmr.com/150698/'),
      ),
      ['https://japaneseasmr.com/embed/player-one'],
    );
  });

  test('JapaneseASMR gateway retries HTTPS and HTTP upstream variants', () {
    expect(
      JapaneseAsmrGatewayParser.gatewayUrls('https://japaneseasmr.com/'),
      <String>[
        'https://r.jina.ai/https://japaneseasmr.com/',
        'https://r.jina.ai/http://japaneseasmr.com/',
      ],
    );
  });

  test('JapaneseASMR verified LKG stays browsable and playable', () {
    final items = JapaneseAsmrGatewayParser.catalog(
      JapaneseAsmrLastKnownGood.catalogMarkdown,
      pageSize: 20,
    );
    expect(items, hasLength(104));
    expect(items.first.ref.localId, 'RJ01717942');
    expect(items.first.ref.detailUrl, 'https://japaneseasmr.com/150698/');
    expect(items.length, greaterThan(100));

    final detail = JapaneseAsmrLastKnownGood.detailMarkdown(
      'https://japaneseasmr.com/150698/',
    );
    expect(detail, isNotNull);
    final normalized = JapaneseAsmrGatewayParser.normalizeDetail(detail!);
    expect(
      SourceHtmlParser.extractPlayableUrls(normalized),
      contains('https://v.weeab0o.xyz/RJ01717942.m3u8'),
    );
  });

  test('JapaneseASMR cover host receives required source headers', () {
    final headers = sourceImageHeadersFor(
      'https://pic.weeabo0.xyz/RJ01717942_img_main.jpg',
    );
    expect(headers, isNotNull);
    expect(headers!['Referer'], 'https://japaneseasmr.com/');
    expect(headers['Origin'], 'https://japaneseasmr.com');
    expect(
      sourceImageHeadersFor('https://example.test/cover.jpg'),
      isNull,
    );
  });

  test('JapaneseASMR gateway markdown keeps catalog, chapters and HLS', () {
    const catalogMarkdown = '''
Title: Japanese ASMR

## [Gateway Work](https://japaneseasmr.com/150698/)

[![Image 1](https://pic.weeabo0.xyz/RJ01717942_img_main.jpg)](https://japaneseasmr.com/150698/)

**[260913][Another] Gateway Work [RJ01717942]**

CV: Kosuzu Momoka
''';

    final candidates = JapaneseAsmrGatewayParser.catalog(
      catalogMarkdown,
      pageSize: 20,
    );
    expect(candidates, hasLength(1));
    expect(candidates.single.ref.localId, 'RJ01717942');
    expect(candidates.single.ref.canonicalId, 'RJ01717942');
    expect(candidates.single.ref.circle, 'Another');
    expect(
      candidates.single.ref.coverUrl,
      'https://pic.weeabo0.xyz/RJ01717942_img_main.jpg',
    );
    expect(candidates.single.work.release, '2026-09-13');

    const detailMarkdown = '''
Title: Gateway Work – Japanese ASMR

**[260913][Another] Gateway Work [RJ01717942]**
CV: Kosuzu Momoka

[Video 7](https://v.weeab0o.xyz/RJ01717942.m3u8)

[00:00:00](https://japaneseasmr.com/150698/#)[track1_First](https://japaneseasmr.com/150698/#)
[00:04:18](https://japaneseasmr.com/150698/#)[track2_Second](https://japaneseasmr.com/150698/#)
[00:11:23](https://japaneseasmr.com/150698/#)[track3_Third](https://japaneseasmr.com/150698/#)

総再生時間: 1時間19分38秒
''';

    final normalized =
        JapaneseAsmrGatewayParser.normalizeDetail(detailMarkdown);
    expect(
      JapaneseAsmrPageParser.title(
        normalized,
        canonical: 'RJ01717942',
      ),
      'Gateway Work',
    );
    expect(JapaneseAsmrPageParser.circle(normalized), 'Another');
    expect(JapaneseAsmrPageParser.releaseDate(normalized), '2026-09-13');

    final chapters = JapaneseAsmrPageParser.chapters(
      normalized,
      totalDurationSeconds:
          JapaneseAsmrPageParser.totalDurationSeconds(normalized),
    );
    expect(chapters, hasLength(3));
    expect(chapters[0].title, 'track1_First');
    expect(chapters[1].startSeconds, 258);
    expect(chapters[2].endSeconds, 4778);

    expect(
      SourceHtmlParser.extractPlayableUrls(detailMarkdown),
      contains('https://v.weeab0o.xyz/RJ01717942.m3u8'),
    );
  });

  test('JapaneseASMR chapter parser de-duplicates repeated track tables', () {
    const html = '''
      <table>
        <tr><td>00:00:00</td><td>Track 1</td></tr>
        <tr><td>00:04:18</td><td>Track 2</td></tr>
      </table>
      <table>
        <tr><td>00:00:00</td><td>Track 1</td></tr>
        <tr><td>00:04:18</td><td>Track 2</td></tr>
      </table>
    ''';

    final chapters = JapaneseAsmrPageParser.chapters(
      html,
      totalDurationSeconds: 683,
    );
    expect(chapters, hasLength(2));
    expect(chapters[0].title, 'Track 1');
    expect(chapters[1].title, 'Track 2');
  });

  test('ASMR+18 parser reads chapter timeline and source metadata', () {
    const html = '''
      <html>
        <head>
          <meta property="og:title"
              content="Chapter Work - 男子向け - 同人ボイス ASMR+18">
          <meta property="og:image" content="/cover.jpg">
        </head>
        <body>
          <h1>Chapter Work</h1>
          <div>2026年9月18日4時</div>
          <div>RJ01717942</div>
          <a href="#bad">String.fromCharCode(c+29):c.toString(36));function(x){return x.replace(/a/g,'b')}00:00:00</a>
          <a href="#t1">track1_First00:00:00</a>
          <a href="#t2">track2_Second00:04:18</a>
          <a href="#t3">track3_Third00:11:23</a>
          <div>
            声優 <a href="/cv/voice/">Kosuzu Momoka</a>
            サークル <a href="/circle/another/">Another</a>
            シナリオ <a href="/scenario/x/">Writer</a>
            ジャンル <a href="/genre/ear/">Ear Cleaning</a>
          </div>
          <p>Track1 First (4:18)</p>
          <p>Track2 Second (7:05)</p>
          <p>Track3 Third (9:44)</p>
          <div>Comments</div>
        </body>
      </html>
    ''';

    expect(Asmr18PageParser.canonicalId(html), 'RJ01717942');
    expect(
      Asmr18PageParser.title(
        html,
        canonical: 'RJ01717942',
      ),
      'Chapter Work',
    );
    expect(
      Asmr18PageParser.releaseDate(html, canonical: 'RJ01717942'),
      '2026-09-18',
    );
    expect(
      Asmr18PageParser.voiceActors(html, canonical: 'RJ01717942'),
      ['Kosuzu Momoka'],
    );
    expect(
      Asmr18PageParser.circle(html, canonical: 'RJ01717942'),
      'Another',
    );
    expect(
      Asmr18PageParser.genres(html, canonical: 'RJ01717942'),
      contains('Ear Cleaning'),
    );

    final chapters = Asmr18PageParser.chapters(html);
    expect(chapters, hasLength(3));
    expect(chapters[0].startSeconds, 0);
    expect(chapters[0].endSeconds, 258);
    expect(chapters[1].startSeconds, 258);
    expect(chapters[1].endSeconds, 683);
    expect(chapters[1].durationSeconds, 425);
    expect(chapters[2].endSeconds, 1267);
    expect(Asmr18PageParser.totalDurationSeconds(html), 1267);
  });

  test('ASMR+18 media candidates prefer URLs exposed by page/player data', () {
    const html = '''
      <audio src="/media/work-part-1.mp3"></audio>
      <audio src="/media/work-part-2.mp3"></audio>
      <script>const stream = "https://cdn.example.test/work/master.m3u8";</script>
    ''';

    final candidates = Asmr18PageParser.playableCandidates(
      html,
      pageUri: Uri.parse('https://asmr18.fans/boys/rj01717942/'),
    );

    expect(
      candidates,
      containsAll(<String>[
        'https://asmr18.fans/media/work-part-1.mp3',
        'https://asmr18.fans/media/work-part-2.mp3',
        'https://cdn.example.test/work/master.m3u8',
      ]),
    );
  });

  test('ASMR Hentai wire codec round-trips API payloads', () {
    const payload = <String, dynamic>{
      'a': 'ja',
      'b': 0,
      'c': 0,
      'd': <String>[],
    };

    final encoded = AsmrHentaiApiCodec.encode(payload);
    final decoded = AsmrHentaiApiCodec.decode(encoded);

    expect(decoded, payload);
  });

  test('ASMR Hentai parser reads catalog and nested playable tracks', () {
    final entries = AsmrHentaiApiParser.catalogEntries(
      const <String, dynamic>{
        'a': <dynamic>[],
        'b': <dynamic>[
          <String, dynamic>{
            'a': 'RJ245055',
            'b': 'Healing Club',
            'c': 'Patissier',
            'd': 'Adult',
          },
        ],
        'c': 145,
      },
      discover: true,
    );
    expect(entries.single['a'], 'RJ245055');

    final tracks = AsmrHentaiApiParser.buildTrackTree(
      'RJ245055',
      const <dynamic>[
        <String, dynamic>{
          'a': '',
          'b': <dynamic>[],
          'c': <dynamic>[
            <String, dynamic>{
              'a': 'With sound effects',
              'b': <dynamic>[
                <String, dynamic>{
                  'a': 'a_x3n',
                  'b': 'A Request from the Students',
                  'c': 178,
                },
              ],
              'c': <dynamic>[],
            },
          ],
        },
      ],
    );

    final folder = Map<String, dynamic>.from(tracks.single as Map);
    final child = Map<String, dynamic>.from(
      (folder['children'] as List).single as Map,
    );
    expect(folder['type'], 'folder');
    expect(child['duration'], 178);
    expect(child['title'], 'A Request from the Students');
    expect(child['sourceTrackId'], 'a_x3n');
    expect(
      child['mediaStreamUrl'],
      'https://newapi.asmrhentai.net/storage/RJ245055/a_x3n.opus',
    );
    expect(child['startOffset'], 0);
    expect(child['endOffset'], 178);
  });

  test('ASMR Hentai source transcript maps timestamps to active track', () {
    const track = AudioTrack(
      id: 'asmr_hentai_net:RJ245055:a_x3n',
      title: 'A Request from the Students',
      url: 'https://newapi.asmrhentai.net/storage/RJ245055/a_x3n.opus',
      duration: Duration(seconds: 178),
      sourceKey: 'asmr_hentai_net',
      sourceWorkId: 'RJ245055',
      sourceTrackId: 'a_x3n',
      startOffset: Duration.zero,
      endOffset: Duration(seconds: 178),
    );

    final result = SourceSubtitleService.parseAsmrHentaiTranscript(
      const <String, dynamic>{
        'a': false,
        'b': <dynamic>[
          <String, dynamic>{'a': 0.5, 'b': 'First line'},
          <String, dynamic>{'a': 4, 'b': 'Second line'},
        ],
      },
      track: track,
    );

    expect(result, isNotNull);
    expect(result!.lyrics, hasLength(2));
    expect(result.lyrics.first.startTime, const Duration(milliseconds: 500));
    expect(result.lyrics.first.endTime, const Duration(seconds: 4));
    expect(result.lyrics.last.endTime, const Duration(seconds: 178));
    expect(
      result.sourceUri,
      'source://asmr_hentai_net/RJ245055/a_x3n',
    );
    expect(result.aiGenerated, isFalse);
  });
}
