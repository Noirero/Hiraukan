import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/extensions/audio_extension.dart';
import 'package:kikoeru_flutter/src/extensions/audio_extension_install_provider.dart';
import 'package:kikoeru_flutter/src/extensions/audio_extension_manifest.dart';
import 'package:kikoeru_flutter/src/extensions/direct_source_audio_extension.dart';
import 'package:kikoeru_flutter/src/extensions/miyorare_audio_pack.dart';
import 'package:kikoeru_flutter/src/models/work.dart';
import 'package:kikoeru_flutter/src/sources/source_adapter.dart';
import 'package:kikoeru_flutter/src/sources/unified_source_models.dart';

void main() {
  test('adapter-backed extension keeps provider detail ref from browse', () async {
    final adapter = _RefSensitiveAdapter();
    final extension = AdapterBackedDirectAudioExtension(
      adapter: adapter,
      manifest: const AudioExtensionManifest(
        id: 'miyorare.audio.ref_test',
        name: 'Ref Test',
        version: '1.0.0',
      ),
      refBuilder: (workId) => UnifiedSourceRef(
        source: UnifiedSourceKind.eroVoice,
        localId: workId,
        detailUrl: workId,
      ),
    );

    final page = await extension.browse(page: 1, pageSize: 20);
    expect(page.items.single.id, 'RJ999999');

    final detail = await extension.getDetail(page.items.single.id);
    expect(detail.title, 'Resolved Detail');
    expect(
      adapter.lastDetailUrl,
      'https://example.test/posts/reference-work',
    );
  });

  test('install rejects a pack declaration incompatible with bundled runtime',
      () async {
    final runtime = _FakeExtension(
      const AudioExtensionManifest(
        id: 'miyorare.audio.compat',
        name: 'Compat',
        version: '1.0.0',
        auth: AudioExtensionAuthRequirement.none,
      ),
    );
    final controller = AudioExtensionInstallController(
      [runtime],
      initialInstalled: const {},
      persist: (_) async {},
    );

    const incompatibleEntry = MiyorareAudioPackEntry(
      manifest: AudioExtensionManifest(
        id: 'miyorare.audio.compat',
        name: 'Compat',
        version: '2.0.0',
        auth: AudioExtensionAuthRequirement.none,
      ),
      deliveryKind: 'builtin',
      runtimeId: 'miyorare.audio.compat',
    );

    expect(
      () => controller.install(incompatibleEntry),
      throwsA(isA<StateError>()),
    );
  });

  test('failed persistence leaves install state unchanged', () async {
    final runtime = _FakeExtension(
      const AudioExtensionManifest(
        id: 'miyorare.audio.rollback',
        name: 'Rollback',
        version: '1.0.0',
      ),
    );
    final controller = AudioExtensionInstallController(
      [runtime],
      initialInstalled: const {},
      persist: (_) async => throw StateError('disk failure'),
    );
    const entry = MiyorareAudioPackEntry(
      manifest: AudioExtensionManifest(
        id: 'miyorare.audio.rollback',
        name: 'Rollback',
        version: '1.0.0',
      ),
      deliveryKind: 'builtin',
      runtimeId: 'miyorare.audio.rollback',
    );

    await expectLater(controller.install(entry), throwsA(isA<StateError>()));
    expect(controller.state.installedIds, isEmpty);
  });
}

class _RefSensitiveAdapter implements UnifiedSourceAdapter {
  String? lastDetailUrl;

  @override
  UnifiedSourceKind get kind => UnifiedSourceKind.eroVoice;

  @override
  Future<SourceSearchPage> search({
    required String keyword,
    required int page,
    required int pageSize,
  }) async {
    return SourceSearchPage(
      items: [
        SourceWorkCandidate(
          work: const Work(
            id: -1,
            title: 'Reference',
            sourceId: 'RJ999999',
          ),
          ref: const UnifiedSourceRef(
            source: UnifiedSourceKind.eroVoice,
            localId: 'RJ999999',
            canonicalId: 'RJ999999',
            detailUrl: 'https://example.test/posts/reference-work',
            title: 'Reference',
          ),
        ),
      ],
      totalCount: 1,
      hasMore: false,
    );
  }

  @override
  Future<Work> loadDetail(UnifiedSourceRef ref) async {
    lastDetailUrl = ref.detailUrl;
    if (ref.detailUrl != 'https://example.test/posts/reference-work') {
      throw StateError('lost provider detail URL');
    }
    return const Work(id: -1, title: 'Resolved Detail');
  }

  @override
  Future<List<dynamic>> loadTracks(UnifiedSourceRef ref) async => const [];

  @override
  Future<UnifiedSourceHealth> checkHealth() async =>
      UnifiedSourceHealth.healthy;
}

class _FakeExtension implements AudioExtension {
  const _FakeExtension(this.manifest);

  @override
  final AudioExtensionManifest manifest;

  @override
  Future<AudioExtensionPage> browse({
    required int page,
    required int pageSize,
  }) async =>
      const AudioExtensionPage(items: [], hasMore: false);

  @override
  Future<AudioExtensionPage> search({
    required String keyword,
    required int page,
    required int pageSize,
  }) async =>
      const AudioExtensionPage(items: [], hasMore: false);

  @override
  Future<AudioExtensionWork> getDetail(String workId) async =>
      AudioExtensionWork(id: workId, title: 'Fake');

  @override
  Future<List<AudioExtensionTrack>> getTracks(String workId) async => const [];

  @override
  Future<AudioPlaybackRequest> resolvePlayback({
    required String workId,
    required String trackId,
  }) async =>
      AudioPlaybackRequest(uri: Uri.parse('https://example.test/a.mp3'));

  @override
  Future<AudioExtensionHealth> checkHealth() async =>
      AudioExtensionHealth.healthy;
}
