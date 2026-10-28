import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/services/portable_backup_sanitizer.dart';

void main() {
  const sanitizer = PortableBackupSanitizer();

  test('removes credential fields and sensitive playback headers', () {
    final sanitized = sanitizer.sanitizeMap({
      'title': 'Track',
      'apiKey': 'secret-key',
      'AWSAccessKeyId': 'access-key-id',
      'secretKey': 'secret-key-value',
      'credentials': 'raw-credential-bundle',
      'playbackHeaders': {
        'Referer': 'https://catalog.example/work/1',
        'Authorization': 'Bearer secret-token',
        'Cookie': 'session=secret',
      },
    });

    expect(sanitized['title'], 'Track');
    expect(sanitized.containsKey('apiKey'), isFalse);
    expect(sanitized.containsKey('AWSAccessKeyId'), isFalse);
    expect(sanitized.containsKey('secretKey'), isFalse);
    expect(sanitized.containsKey('credentials'), isFalse);

    final headers = Map<String, dynamic>.from(
      sanitized['playbackHeaders'] as Map,
    );
    expect(headers['Referer'], 'https://catalog.example/work/1');
    expect(headers.containsKey('Authorization'), isFalse);
    expect(headers.containsKey('Cookie'), isFalse);
  });

  test('redacts token, signatures, access keys, user info, and fragments from URLs', () {
    final sanitized = sanitizer.sanitizeMap({
      'url':
          'https://user:password@media.example/audio.mp3?id=42&token=secret&AWSAccessKeyId=access-key&sig=short-signature&X-Amz-Signature=signed#access_token=fragment',
    });

    final uri = Uri.parse(sanitized['url'] as String);
    expect(uri.userInfo, isEmpty);
    expect(uri.fragment, isEmpty);
    expect(uri.queryParameters['id'], '42');
    expect(uri.queryParameters.containsKey('token'), isFalse);
    expect(uri.queryParameters.keys.any(
      (key) => key.toLowerCase().contains('accesskey'),
    ), isFalse);
    expect(uri.queryParameters.keys.any(
      (key) => key.toLowerCase() == 'sig',
    ), isFalse);
    expect(uri.queryParameters.keys.any(
      (key) => key.toLowerCase().contains('signature'),
    ), isFalse);
  });

  test('removes a query entirely when every parameter is sensitive', () {
    final sanitized = sanitizer.sanitizeMap({
      'url': 'https://media.example/audio.mp3?token=secret&auth=other',
    });

    final uri = Uri.parse(sanitized['url'] as String);
    expect(uri.query, isEmpty);
  });

  test('leaves non-url metadata and safe URLs unchanged', () {
    final sanitized = sanitizer.sanitizeMap({
      'note': 'token= is mentioned as plain text',
      'sourceUrl': 'https://catalog.example/work/1?lang=ja',
    });

    expect(sanitized['note'], 'token= is mentioned as plain text');
    expect(sanitized['sourceUrl'], 'https://catalog.example/work/1?lang=ja');
  });
}
