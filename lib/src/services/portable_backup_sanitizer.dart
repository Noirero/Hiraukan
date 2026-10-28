class PortableBackupSanitizer {
  const PortableBackupSanitizer();

  static const Set<String> _sensitiveMapKeys = <String>{
    'authorization',
    'proxyauthorization',
    'cookie',
    'setcookie',
    'token',
    'accesstoken',
    'refreshtoken',
    'apikey',
    'xapikey',
    'accesskey',
    'accesskeyid',
    'password',
    'secret',
    'secretkey',
    'privatekey',
    'clientsecret',
    'credential',
    'credentials',
    'session',
    'sessionid',
    'sessiontoken',
  };

  Map<String, dynamic> sanitizeMap(Map<String, dynamic> source) {
    final result = <String, dynamic>{};
    for (final entry in source.entries) {
      if (_isSensitiveMapKey(entry.key)) continue;
      result[entry.key] = sanitizeValue(entry.value);
    }
    return result;
  }

  dynamic sanitizeValue(dynamic value) {
    if (value is Map) {
      return sanitizeMap(Map<String, dynamic>.from(value));
    }
    if (value is List) {
      return value.map(sanitizeValue).toList(growable: false);
    }
    if (value is String) {
      return _sanitizeUrl(value);
    }
    return value;
  }

  bool _isSensitiveMapKey(String key) {
    final normalized = _normalizeKey(key);
    return _sensitiveMapKeys.contains(normalized) ||
        normalized.endsWith('token') ||
        normalized.contains('authorization') ||
        normalized.contains('apikey') ||
        normalized.contains('credential') ||
        normalized.endsWith('accesskey') ||
        normalized.endsWith('accesskeyid') ||
        normalized.endsWith('password') ||
        normalized.endsWith('secret') ||
        normalized.endsWith('secretkey') ||
        normalized.endsWith('privatekey');
  }

  bool _isSensitiveQueryKey(String key) {
    final normalized = _normalizeKey(key);
    return _sensitiveMapKeys.contains(normalized) ||
        normalized == 'key' ||
        normalized == 'auth' ||
        normalized == 'sig' ||
        normalized.contains('token') ||
        normalized.contains('signature') ||
        normalized.contains('credential') ||
        normalized.contains('apikey') ||
        normalized.contains('accesskey') ||
        normalized.contains('secret') ||
        normalized.contains('privatekey') ||
        normalized.contains('password');
  }

  String _sanitizeUrl(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return raw;
    }

    final cleanQuery = <String, dynamic>{};
    var removedSensitiveQuery = false;
    for (final entry in uri.queryParametersAll.entries) {
      if (_isSensitiveQueryKey(entry.key)) {
        removedSensitiveQuery = true;
        continue;
      }
      cleanQuery[entry.key] = entry.value;
    }

    final hasSensitiveUserInfo = uri.userInfo.isNotEmpty;
    final hasFragment = uri.fragment.isNotEmpty;
    if (!removedSensitiveQuery && !hasSensitiveUserInfo && !hasFragment) {
      return raw;
    }

    return uri
        .replace(
          userInfo: '',
          queryParameters: cleanQuery,
          fragment: '',
        )
        .toString();
  }

  String _normalizeKey(String key) {
    return key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }
}
