import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../models/audio_track.dart';
import '../utils/local_file_url.dart';
import 'kikoflu_feature_settings.dart';

class OnlineAsrNotConfiguredException implements Exception {
  const OnlineAsrNotConfiguredException();

  @override
  String toString() => 'Online ASR endpoint is not configured.';
}

class OnlineAsrInvalidResponseException implements Exception {
  final String message;

  const OnlineAsrInvalidResponseException(this.message);

  @override
  String toString() => message;
}

class OnlineAsrSegment {
  final double startSeconds;
  final double endSeconds;
  final String text;

  const OnlineAsrSegment({
    required this.startSeconds,
    required this.endSeconds,
    required this.text,
  });
}

class OnlineAsrResult {
  final List<OnlineAsrSegment> segments;
  final String serviceName;

  const OnlineAsrResult({
    required this.segments,
    required this.serviceName,
  });
}

/// Thin online-ASR client used by the automatic subtitle fallback.
///
/// Contract accepted by the Hiraukan gateway:
/// - remote track: JSON {audio_url, language, response_format}
/// - local track: multipart field "audio" plus language/response_format
/// - response: {segments:[{start,end,text}]} (seconds), with start_ms/end_ms
///   also accepted.
///
/// The client deliberately contains no ASR model and never downloads one.
class OnlineAsrService {
  OnlineAsrService._();

  static final OnlineAsrService instance = OnlineAsrService._();

  static const String engineId = 'hiraukan_online_asr';
  static const String engineVersion = 'gateway-v1';
  static const String cacheProfile = 'ja-online-v1';

  Future<OnlineAsrResult> transcribe(
    AudioTrack track, {
    bool Function()? isCancelled,
  }) async {
    final settings = KikoFluFeatureSettings.instance;
    final endpoint = settings.onlineAsrEndpoint.trim();
    if (endpoint.isEmpty) {
      throw const OnlineAsrNotConfiguredException();
    }
    final uri = Uri.tryParse(endpoint);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      throw const OnlineAsrInvalidResponseException(
        'Online ASR endpoint must use HTTP or HTTPS.',
      );
    }
    if (isCancelled?.call() == true) {
      throw const OnlineAsrInvalidResponseException('Online ASR cancelled.');
    }

    final headers = <String, String>{'Accept': 'application/json'};
    final token = settings.onlineAsrToken.trim();
    if (token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(minutes: 20),
        receiveTimeout: const Duration(minutes: 20),
        headers: headers,
      ),
    );

    final localPath = _existingLocalPath(track);
    final Response<dynamic> response;
    if (localPath != null) {
      final file = File(localPath);
      response = await dio.post<dynamic>(
        endpoint,
        data: FormData.fromMap({
          'audio': await MultipartFile.fromFile(
            localPath,
            filename: file.uri.pathSegments.isEmpty
                ? 'audio'
                : file.uri.pathSegments.last,
          ),
          'language': 'ja',
          'response_format': 'verbose_json',
        }),
      );
    } else {
      final audioUri = Uri.tryParse(track.url);
      if (audioUri == null ||
          !(audioUri.scheme == 'http' || audioUri.scheme == 'https')) {
        throw const OnlineAsrInvalidResponseException(
          'Audio source is not available for online ASR.',
        );
      }
      response = await dio.post<dynamic>(
        endpoint,
        data: <String, dynamic>{
          'audio_url': track.url,
          'language': 'ja',
          'response_format': 'verbose_json',
          'track_id': track.id,
          if (track.sourceKey != null) 'source': track.sourceKey,
          if (track.sourceWorkId != null) 'work_id': track.sourceWorkId,
        },
      );
    }

    if (isCancelled?.call() == true) {
      throw const OnlineAsrInvalidResponseException('Online ASR cancelled.');
    }

    final decoded = _decodeBody(response.data);
    final rawSegments = _segmentsFrom(decoded);
    final segments = <OnlineAsrSegment>[];

    for (final raw in rawSegments) {
      if (raw is! Map) continue;
      final text = raw['text']?.toString().trim() ?? '';
      if (text.isEmpty) continue;

      final start = _seconds(raw, 'start', 'start_ms');
      final end = _seconds(raw, 'end', 'end_ms');
      if (start == null || end == null || end < start) continue;

      segments.add(
        OnlineAsrSegment(
          startSeconds: start,
          endSeconds: end,
          text: text,
        ),
      );
    }

    if (segments.isEmpty) {
      throw const OnlineAsrInvalidResponseException(
        'Online ASR returned no timed Japanese segments.',
      );
    }

    final serviceName =
        decoded is Map && decoded['service'] != null
            ? decoded['service'].toString()
            : 'online';
    return OnlineAsrResult(
      segments: List.unmodifiable(segments),
      serviceName: serviceName,
    );
  }

  String? _existingLocalPath(AudioTrack track) {
    for (final candidate in <String?>[
      track.sourcePath,
      LocalFileUrl.pathFromUrl(track.url),
    ]) {
      if (candidate == null || candidate.isEmpty) continue;
      if (File(candidate).existsSync()) return candidate;
    }
    return null;
  }

  dynamic _decodeBody(dynamic data) {
    if (data is String) {
      try {
        return jsonDecode(data);
      } catch (_) {
        throw const OnlineAsrInvalidResponseException(
          'Online ASR returned invalid JSON.',
        );
      }
    }
    return data;
  }

  List<dynamic> _segmentsFrom(dynamic decoded) {
    if (decoded is Map) {
      final direct = decoded['segments'];
      if (direct is List) return direct;
      final nested = decoded['data'];
      if (nested is Map && nested['segments'] is List) {
        return nested['segments'] as List<dynamic>;
      }
    }
    throw const OnlineAsrInvalidResponseException(
      'Online ASR response has no segments array.',
    );
  }

  double? _seconds(Map raw, String secondsKey, String millisKey) {
    final seconds = _number(raw[secondsKey]);
    if (seconds != null) return seconds;
    final millis = _number(raw[millisKey]);
    return millis == null ? null : millis / 1000.0;
  }

  double? _number(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
