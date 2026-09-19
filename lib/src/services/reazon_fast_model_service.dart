import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum FastAsrModelState {
  notInstalled,
  downloading,
  verifying,
  ready,
  corrupt,
  failed,
}

class ReazonFastModelStatus {
  final FastAsrModelState state;
  final int installedBytes;
  final int expectedBytes;
  final String? message;

  const ReazonFastModelStatus({
    required this.state,
    required this.installedBytes,
    required this.expectedBytes,
    this.message,
  });

  bool get isReady => state == FastAsrModelState.ready;
}

class ReazonFastModelPaths {
  final String encoder;
  final String decoder;
  final String joiner;
  final String tokens;

  const ReazonFastModelPaths({
    required this.encoder,
    required this.decoder,
    required this.joiner,
    required this.tokens,
  });
}

class ReazonFastModelService {
  ReazonFastModelService._();

  static final ReazonFastModelService instance = ReazonFastModelService._();

  static const modelId = 'reazonspeech-k2-v2-fast';
  static const modelRevision =
      'a454b3fe1e63f4189ae3994248aeb3d31b6682f4';
  static const license = 'Apache-2.0';
  static const repository =
      'https://huggingface.co/reazon-research/reazonspeech-k2-v2';

  // sherpa-onnx's current Reazon configuration uses an INT8 encoder and
  // joiner with the float decoder.
  static const files = <_ModelFile>[
    _ModelFile(
      name: 'encoder-epoch-99-avg-1.int8.onnx',
      expectedBytes: 154670139,
      sha256:
          '2c7bd08a8a99f9ddd0d9e458456577b1f6279214e51426f114f9eced44c54e1d',
    ),
    _ModelFile(
      name: 'decoder-epoch-99-avg-1.onnx',
      expectedBytes: 11767836,
      sha256:
          '58b18211ae06265466bfa17172dab574df94f76c8bcb61a3640c28ba860e4124',
    ),
    _ModelFile(
      name: 'joiner-epoch-99-avg-1.int8.onnx',
      expectedBytes: 2696970,
      sha256:
          '49cc7ea1d3d35a40a27442db5e89996da64bf0e683a903dce76e99e57a12e4de',
    ),
    // tokens.txt is a normal Git object rather than an LFS object. Its source
    // URL is pinned to the immutable model revision and we persist its SHA-256
    // after the first verified structural download for later integrity checks.
    _ModelFile(
      name: 'tokens.txt',
      expectedBytes: 0,
      sha256: null,
    ),
  ];

  static int get expectedWeightBytes => files
      .where((file) => file.expectedBytes > 0)
      .fold(0, (sum, file) => sum + file.expectedBytes);

  Future<Directory> modelDirectory() async {
    final support = await getApplicationSupportDirectory();
    return Directory(
      p.join(support.path, 'hiraukan_ai', 'asr', modelId),
    );
  }

  Future<ReazonFastModelPaths> paths() async {
    final dir = await modelDirectory();
    return ReazonFastModelPaths(
      encoder: p.join(dir.path, files[0].name),
      decoder: p.join(dir.path, files[1].name),
      joiner: p.join(dir.path, files[2].name),
      tokens: p.join(dir.path, files[3].name),
    );
  }

  Future<ReazonFastModelStatus> status() async {
    final dir = await modelDirectory();
    if (!await dir.exists()) {
      return ReazonFastModelStatus(
        state: FastAsrModelState.notInstalled,
        installedBytes: 0,
        expectedBytes: expectedWeightBytes,
      );
    }

    final recordedHashes = await _readInstalledHashes(dir);
    var installedBytes = 0;
    var anyFile = false;

    for (final spec in files) {
      final file = File(p.join(dir.path, spec.name));
      if (!await file.exists()) continue;
      anyFile = true;
      installedBytes += await file.length();

      final valid = await _verifyFile(
        file,
        spec,
        recordedHash: recordedHashes[spec.name],
      );
      if (!valid) {
        return ReazonFastModelStatus(
          state: FastAsrModelState.corrupt,
          installedBytes: installedBytes,
          expectedBytes: expectedWeightBytes,
          message: 'File model rusak/tidak cocok: ${spec.name}',
        );
      }
    }

    final allPresent = await Future.wait(
      files.map((spec) => File(p.join(dir.path, spec.name)).exists()),
    ).then((values) => values.every((value) => value));

    if (!allPresent) {
      return ReazonFastModelStatus(
        state: anyFile
            ? FastAsrModelState.corrupt
            : FastAsrModelState.notInstalled,
        installedBytes: installedBytes,
        expectedBytes: expectedWeightBytes,
        message: anyFile ? 'Model Fast belum lengkap.' : null,
      );
    }

    return ReazonFastModelStatus(
      state: FastAsrModelState.ready,
      installedBytes: installedBytes,
      expectedBytes: expectedWeightBytes,
    );
  }

  Future<ReazonFastModelStatus> download({
    void Function(int received, int total, String fileName)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final dir = await modelDirectory();
    await dir.create(recursive: true);

    final installedHashes = <String, String>{};
    var completedBytes = 0;
    final estimatedTokenBytes = 46 * 1024;
    final totalBytes = expectedWeightBytes + estimatedTokenBytes;

    for (final spec in files) {
      if (isCancelled?.call() == true) {
        throw const ReazonFastDownloadCancelledException();
      }

      final destination = File(p.join(dir.path, spec.name));
      if (await destination.exists() &&
          await _verifyFile(
            destination,
            spec,
            recordedHash: (await _readInstalledHashes(dir))[spec.name],
          )) {
        final length = await destination.length();
        completedBytes += length;
        installedHashes[spec.name] = await _sha256File(destination);
        onProgress?.call(completedBytes, totalBytes, spec.name);
        continue;
      }

      if (await destination.exists()) {
        await destination.delete();
      }

      final part = File('${destination.path}.part');
      await _downloadFile(
        spec,
        part,
        baseCompletedBytes: completedBytes,
        totalBytes: totalBytes,
        onProgress: onProgress,
        isCancelled: isCancelled,
      );

      if (!await _verifyFile(part, spec, recordedHash: null)) {
        if (await part.exists()) await part.delete();
        throw StateError('Model integrity check failed: ${spec.name}');
      }

      if (await destination.exists()) await destination.delete();
      await part.rename(destination.path);
      final length = await destination.length();
      completedBytes += length;
      installedHashes[spec.name] = await _sha256File(destination);
      onProgress?.call(completedBytes, totalBytes, spec.name);
    }

    await _writeInstalledManifest(dir, installedHashes);
    final finalStatus = await status();
    if (!finalStatus.isReady) {
      throw StateError(finalStatus.message ?? 'Fast ASR model is not ready');
    }
    return finalStatus;
  }

  Future<void> delete() async {
    final dir = await modelDirectory();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  Future<void> _downloadFile(
    _ModelFile spec,
    File part, {
    required int baseCompletedBytes,
    required int totalBytes,
    required void Function(int received, int total, String fileName)?
        onProgress,
    required bool Function()? isCancelled,
  }) async {
    await part.parent.create(recursive: true);
    var existing = await part.exists() ? await part.length() : 0;

    final uri = Uri.parse(
      '$repository/resolve/$modelRevision/${spec.name}?download=true',
    );
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);

    try {
      var request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
      if (existing > 0) {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$existing-');
      }
      var response = await request.close();

      if (existing > 0 && response.statusCode == HttpStatus.ok) {
        existing = 0;
        if (await part.exists()) await part.delete();
      } else if (response.statusCode != HttpStatus.ok &&
          response.statusCode != HttpStatus.partialContent) {
        throw HttpException(
          'Download failed for ${spec.name}: ${response.statusCode}',
          uri: uri,
        );
      }

      final sink = part.openWrite(
        mode: existing > 0 ? FileMode.append : FileMode.write,
      );
      var received = existing;
      try {
        await for (final chunk in response) {
          if (isCancelled?.call() == true) {
            throw const ReazonFastDownloadCancelledException();
          }
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(
            baseCompletedBytes + received,
            totalBytes,
            spec.name,
          );
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
    } finally {
      client.close(force: true);
    }
  }

  Future<bool> _verifyFile(
    File file,
    _ModelFile spec, {
    required String? recordedHash,
  }) async {
    if (!await file.exists()) return false;
    final length = await file.length();

    if (spec.expectedBytes > 0 && length != spec.expectedBytes) {
      return false;
    }
    if (spec.name == 'tokens.txt') {
      if (length < 40000 || length > 60000) return false;
      final text = await file.readAsString();
      final lines = const LineSplitter().convert(text);
      if (lines.length < 5000 ||
          !lines.first.startsWith('<blk>') ||
          !lines.any((line) => line.startsWith('あ'))) {
        return false;
      }
    }

    final expectedHash = spec.sha256 ?? recordedHash;
    if (expectedHash == null) return true;
    return await _sha256File(file) == expectedHash;
  }

  Future<String> _sha256File(File file) async {
    return (await sha256.bind(file.openRead()).first).toString();
  }

  Future<Map<String, String>> _readInstalledHashes(Directory dir) async {
    final manifest = File(p.join(dir.path, 'installed_manifest.json'));
    if (!await manifest.exists()) return const {};
    try {
      final decoded = jsonDecode(await manifest.readAsString());
      if (decoded is! Map) return const {};
      final hashes = decoded['sha256'];
      if (hashes is! Map) return const {};
      return hashes.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    } catch (_) {
      return const {};
    }
  }

  Future<void> _writeInstalledManifest(
    Directory dir,
    Map<String, String> hashes,
  ) async {
    final destination = File(p.join(dir.path, 'installed_manifest.json'));
    final temporary = File('${destination.path}.tmp');
    final payload = jsonEncode({
      'modelId': modelId,
      'revision': modelRevision,
      'runtime': 'sherpa-onnx-1.13.8',
      'license': license,
      'sha256': hashes,
      'installedAt': DateTime.now().toUtc().toIso8601String(),
    });
    await temporary.writeAsString(payload, flush: true);
    if (await destination.exists()) await destination.delete();
    await temporary.rename(destination.path);
  }
}

class _ModelFile {
  final String name;
  final int expectedBytes;
  final String? sha256;

  const _ModelFile({
    required this.name,
    required this.expectedBytes,
    required this.sha256,
  });
}

class ReazonFastDownloadCancelledException implements Exception {
  const ReazonFastDownloadCancelledException();

  @override
  String toString() => 'Fast ASR model download cancelled';
}
