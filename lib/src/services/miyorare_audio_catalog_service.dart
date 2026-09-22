import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../extensions/miyorare_audio_pack.dart';
import 'storage_service.dart';

class MiyorareAudioCatalogSnapshot {
  final MiyorareAudioPack pack;
  final String releaseTag;
  final bool fromCache;

  const MiyorareAudioCatalogSnapshot({
    required this.pack,
    required this.releaseTag,
    required this.fromCache,
  });
}

class MiyorareAudioCatalogService {
  static const String _latestReleaseApi =
      'https://api.github.com/repos/Noirero/Miyorare-Source-Packs/releases/latest';
  static const String catalogAssetName = 'miyorare-audio-extensions.json';
  static const String releaseLockAssetName = 'miyorare-release-lock.json';
  static const String releaseLockChecksumAssetName =
      'miyorare-release-lock.sha256';

  static const String _cacheJsonKey = 'miyorare_audio_catalog_lkg_json';
  static const String _cacheDigestKey = 'miyorare_audio_catalog_lkg_sha256';
  static const String _cacheTagKey = 'miyorare_audio_catalog_lkg_tag';

  final Dio _dio;

  MiyorareAudioCatalogService({Dio? dio}) : _dio = dio ?? Dio();

  Future<MiyorareAudioCatalogSnapshot?> loadLatest() async {
    try {
      final remote = await _loadRemote();
      return remote ?? await loadLastKnownGood();
    } catch (_) {
      return loadLastKnownGood();
    }
  }

  static Set<String>? lastKnownGoodExtensionIds() {
    final raw = StorageService.getString(_cacheJsonKey);
    final digest = StorageService.getString(_cacheDigestKey);
    if (raw == null || digest == null) return null;

    final bytes = utf8.encode(raw);
    if (sha256.convert(bytes).toString() != digest) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final pack = MiyorareAudioPack.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      return pack.extensions
          .map((entry) => entry.runtimeId)
          .toSet();
    } catch (_) {
      return null;
    }
  }

  Future<MiyorareAudioCatalogSnapshot?> loadLastKnownGood() async {
    final raw = StorageService.getString(_cacheJsonKey);
    final digest = StorageService.getString(_cacheDigestKey);
    final tag = StorageService.getString(_cacheTagKey);
    if (raw == null || digest == null || tag == null) return null;

    final bytes = utf8.encode(raw);
    if (sha256.convert(bytes).toString() != digest) {
      await _clearCache();
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final pack = MiyorareAudioPack.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      return MiyorareAudioCatalogSnapshot(
        pack: pack,
        releaseTag: tag,
        fromCache: true,
      );
    } catch (_) {
      await _clearCache();
      return null;
    }
  }

  Future<MiyorareAudioCatalogSnapshot?> _loadRemote() async {
    final releaseResponse = await _dio.get<dynamic>(
      _latestReleaseApi,
      options: Options(
        headers: const {'Accept': 'application/vnd.github+json'},
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    if (releaseResponse.statusCode != 200 || releaseResponse.data is! Map) {
      throw StateError('Miyorare Source Pack release metadata unavailable');
    }

    final release = Map<String, dynamic>.from(releaseResponse.data as Map);
    if (release['draft'] == true || release['prerelease'] == true) {
      throw StateError('Latest Miyorare Source Pack release is not stable');
    }

    final tag = release['tag_name']?.toString() ?? '';
    if (!RegExp(r'^miyorare-sources-v\d+\.\d+\.\d+$').hasMatch(tag)) {
      throw StateError('Unexpected Miyorare Source Pack release tag');
    }

    final assets = release['assets'];
    if (assets is! List) {
      throw StateError('Miyorare Source Pack release has no assets');
    }

    Map<String, dynamic>? asset(String name) {
      for (final raw in assets) {
        if (raw is Map && raw['name'] == name) {
          return Map<String, dynamic>.from(raw);
        }
      }
      return null;
    }

    final catalogAsset = asset(catalogAssetName);
    if (catalogAsset == null) {
      // Stable releases created before Audio Pack support are valid, but do
      // not provide a remote catalog. The caller will use the local LKG/builtin
      // runtimes instead.
      return null;
    }
    final lockAsset = asset(releaseLockAssetName);
    final checksumAsset = asset(releaseLockChecksumAssetName);
    if (lockAsset == null || checksumAsset == null) {
      throw StateError('Audio catalog release is missing its seal assets');
    }

    final catalogBytes = await _downloadAsset(catalogAsset);
    final lockBytes = await _downloadAsset(lockAsset);
    final checksumBytes = await _downloadAsset(checksumAsset);

    verifyReleaseLock(
      releaseTag: tag,
      catalogBytes: catalogBytes,
      lockBytes: lockBytes,
      lockChecksumBytes: checksumBytes,
    );

    final rawCatalog = utf8.decode(catalogBytes);
    final decoded = jsonDecode(rawCatalog);
    if (decoded is! Map) {
      throw StateError('Miyorare audio catalog is not a JSON object');
    }
    final pack = MiyorareAudioPack.fromJson(
      Map<String, dynamic>.from(decoded),
    );

    final digest = sha256.convert(catalogBytes).toString();
    await StorageService.setString(_cacheJsonKey, rawCatalog);
    await StorageService.setString(_cacheDigestKey, digest);
    await StorageService.setString(_cacheTagKey, tag);

    return MiyorareAudioCatalogSnapshot(
      pack: pack,
      releaseTag: tag,
      fromCache: false,
    );
  }

  Future<List<int>> _downloadAsset(Map<String, dynamic> asset) async {
    final url = asset['browser_download_url']?.toString() ?? '';
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        (uri.host != 'github.com' && uri.host != 'objects.githubusercontent.com')) {
      throw StateError('Unexpected Miyorare release asset origin');
    }

    final response = await _dio.get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        followRedirects: true,
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
    final bytes = response.data;
    if (response.statusCode != 200 || bytes == null || bytes.isEmpty) {
      throw StateError('Failed to download Miyorare release asset');
    }

    final expectedSize = asset['size'];
    if (expectedSize is int && expectedSize > 0 && bytes.length != expectedSize) {
      throw StateError('Miyorare release asset size mismatch');
    }
    return bytes;
  }

  static void verifyReleaseLock({
    required String releaseTag,
    required List<int> catalogBytes,
    required List<int> lockBytes,
    required List<int> lockChecksumBytes,
  }) {
    final checksumText = utf8.decode(lockChecksumBytes).trim();
    final checksumParts = checksumText.split(RegExp(r'\s+'));
    if (checksumParts.length < 2 ||
        checksumParts[1] != releaseLockAssetName ||
        checksumParts[0].toLowerCase() != sha256.convert(lockBytes).toString()) {
      throw StateError('Miyorare release-lock checksum mismatch');
    }

    final decoded = jsonDecode(utf8.decode(lockBytes));
    if (decoded is! Map) {
      throw StateError('Miyorare release lock is invalid');
    }
    final lock = Map<String, dynamic>.from(decoded);
    if (lock['schemaVersion'] != 1 ||
        lock['kind'] != 'MIYORARE_SOURCE_PACK_RELEASE_LOCK' ||
        lock['immutable'] != true ||
        lock['sealedBeforePublish'] != true ||
        lock['tag'] != releaseTag) {
      throw StateError('Miyorare release lock does not satisfy trust policy');
    }

    final assets = lock['assets'];
    if (assets is! List) {
      throw StateError('Miyorare release lock binds no assets');
    }

    Map<String, dynamic>? bound;
    for (final raw in assets) {
      if (raw is Map && raw['name'] == catalogAssetName) {
        bound = Map<String, dynamic>.from(raw);
        break;
      }
    }
    if (bound == null) {
      throw StateError('Miyorare release lock does not bind audio catalog');
    }

    final expectedSize = bound['size'];
    final expectedDigest = bound['sha256']?.toString().toLowerCase();
    final actualDigest = sha256.convert(catalogBytes).toString();
    if (expectedSize != catalogBytes.length || expectedDigest != actualDigest) {
      throw StateError('Miyorare audio catalog failed release-lock validation');
    }
  }

  Future<void> _clearCache() async {
    await StorageService.remove(_cacheJsonKey);
    await StorageService.remove(_cacheDigestKey);
    await StorageService.remove(_cacheTagKey);
  }
}
