import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/extensions/asmr18_audio_extension.dart';
import 'package:kikoeru_flutter/src/extensions/asmr_hentai_net_audio_extension.dart';
import 'package:kikoeru_flutter/src/extensions/audio_extension_manifest.dart';
import 'package:kikoeru_flutter/src/extensions/japanese_asmr_audio_extension.dart';
import 'package:kikoeru_flutter/src/sources/asmr_hentai_net_source_adapter.dart';
import 'package:kikoeru_flutter/src/sources/source_html_parser.dart';

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
    expect(
      hentaiNet.capabilities,
      isNot(contains(AudioExtensionCapability.playback)),
    );
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
    expect(child.containsKey('mediaStreamUrl'), isFalse);
  });
}
