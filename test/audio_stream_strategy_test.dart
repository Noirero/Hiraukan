import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/models/audio_track.dart';
import 'package:kikoeru_flutter/src/services/audio_stream_strategy.dart';

void main() {
  test('new external Unified Sources bypass byte-stream cache', () {
    const tracks = <AudioTrack>[
      AudioTrack(
        id: 'jp',
        title: 'Japanese HLS',
        url: 'https://v.weeab0o.xyz/RJ01717942.m3u8',
        sourceKey: 'japanese_asmr',
      ),
      AudioTrack(
        id: '18',
        title: 'ASMR+18 HLS',
        url: 'https://cdn3.cloudintech.net/file/RJ01717942/RJ01717942.m3u8',
        sourceKey: 'asmr18',
      ),
      AudioTrack(
        id: 'hn',
        title: 'ASMR Hentai Opus',
        url: 'https://newapi.asmrhentai.net/storage/RJ245055/a_x3n.opus',
        sourceKey: 'asmr_hentai_net',
      ),
    ];

    for (final track in tracks) {
      expect(AudioStreamStrategy.shouldUseCachingStream(track), isFalse);
    }
  });

  test('ASMR Hentai can retry with header-aware range transport', () {
    const hentai = AudioTrack(
      id: 'hn-fallback',
      title: 'ASMR Hentai Opus',
      url: 'https://newapi.asmrhentai.net/storage/RJ245055/a_x3n.opus',
      sourceKey: 'asmr_hentai_net',
      playbackHeaders: <String, String>{
        'Referer': 'https://asmrhentai.net',
      },
    );
    const asmr18 = AudioTrack(
      id: '18-no-fallback',
      title: 'ASMR+18 HLS',
      url: 'https://cdn3.cloudintech.net/file/RJ01683528/RJ01683528.m3u8',
      sourceKey: 'asmr18',
      playbackHeaders: <String, String>{
        'Referer': 'https://asmr18.fans/',
      },
    );

    expect(AudioStreamStrategy.shouldTryHeaderAwareFallback(hentai), isTrue);
    expect(AudioStreamStrategy.shouldTryHeaderAwareFallback(asmr18), isFalse);
  });

  test('HLS always bypasses byte-stream cache', () {
    const track = AudioTrack(
      id: 'hls',
      title: 'Adaptive stream',
      url: 'https://example.test/master.m3u8?token=abc',
      sourceKey: 'legacy',
    );

    expect(AudioStreamStrategy.shouldUseCachingStream(track), isFalse);
  });

  test('existing cache-safe direct audio remains cacheable', () {
    const track = AudioTrack(
      id: 'native',
      title: 'Native source',
      url: 'https://example.test/media/file.mp3',
      sourceKey: 'asmr_one',
    );

    expect(AudioStreamStrategy.shouldUseCachingStream(track), isTrue);
  });
}
