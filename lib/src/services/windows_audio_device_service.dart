import 'dart:convert';
import 'dart:ffi';
import 'dart:io' show Platform;

import 'package:ffi/ffi.dart';

class WindowsAudioDevice {
  final String id;
  final String fullId;
  final String name;
  final String friendlyName;
  final String desc;
  final String iface;
  final int formFactor;
  final bool isDefault;

  const WindowsAudioDevice({
    required this.id,
    required this.fullId,
    required this.name,
    this.friendlyName = '',
    this.desc = '',
    this.iface = '',
    this.formFactor = -1,
    this.isDefault = false,
  });

  String get mpvDeviceId => 'wasapi/$id';

  bool get isLikelyUsbDac {
    final lower = name.toLowerCase();
    const dacLikeFormFactors = {7, 8, 9};
    return lower.contains('usb') ||
        lower.contains('dac') ||
        dacLikeFormFactors.contains(formFactor);
  }

  static String _bestName(String friendlyName, String desc, String iface) {
    final candidates = [friendlyName, desc, iface]
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    if (candidates.isEmpty) return 'Unknown audio device';
    bool specific(String value) {
      final lower = value.toLowerCase();
      return lower.contains('usb') || lower.contains('dac');
    }

    final specificNames = candidates.where(specific).toList();
    final pool = specificNames.isNotEmpty ? specificNames : candidates;
    pool.sort((a, b) => b.length.compareTo(a.length));
    return pool.first;
  }
}

/// Enumerates active Windows WASAPI render endpoints through a tiny native
/// helper compiled into the Hiraukan runner. The returned IDs are directly
/// compatible with mpv's `audio-device=wasapi/<id>` option.
class WindowsAudioDeviceService {
  WindowsAudioDeviceService._();
  static final instance = WindowsAudioDeviceService._();

  static const _endpointPrefix = '{0.0.0.00000000}.';
  static DynamicLibrary? _library;
  static _EnumerateDart? _enumerate;
  static _FreeDart? _free;

  bool get isSupported => Platform.isWindows;

  static bool _load() {
    if (_enumerate != null && _free != null) return true;
    try {
      final library = DynamicLibrary.process();
      _enumerate = library.lookupFunction<_EnumerateNative, _EnumerateDart>(
        'hiraukan_enumerate_audio_devices',
      );
      _free = library.lookupFunction<_FreeNative, _FreeDart>(
        'hiraukan_free_string',
      );
      _library = library;
      return true;
    } catch (_) {
      _library = DynamicLibrary.process();
      return false;
    }
  }

  List<WindowsAudioDevice> getOutputDevices() {
    if (!isSupported || !_load()) return const [];
    Pointer<Utf16> pointer;
    try {
      pointer = _enumerate!();
    } catch (_) {
      return const [];
    }
    if (pointer == nullptr) return const [];

    try {
      final raw = pointer.toDartString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const [];
      final defaultId = decoded['default'] is String ? decoded['default'] as String : '';
      final devices = decoded['devices'];
      if (devices is! List) return const [];
      return [
        for (final item in devices)
          if (item is Map) _fromMap(item, defaultFullId: defaultId),
      ];
    } catch (_) {
      return const [];
    } finally {
      _free!(pointer);
    }
  }

  WindowsAudioDevice _fromMap(Map item, {required String defaultFullId}) {
    final fullId = item['fullId'] is String ? item['fullId'] as String : '';
    final friendlyName = item['name'] is String ? item['name'] as String : '';
    final desc = item['desc'] is String ? item['desc'] as String : '';
    final iface = item['iface'] is String ? item['iface'] as String : '';
    final formFactor = item['formFactor'] is num
        ? (item['formFactor'] as num).toInt()
        : -1;
    return WindowsAudioDevice(
      id: fullId.startsWith(_endpointPrefix)
          ? fullId.substring(_endpointPrefix.length)
          : fullId,
      fullId: fullId,
      name: WindowsAudioDevice._bestName(friendlyName, desc, iface),
      friendlyName: friendlyName,
      desc: desc,
      iface: iface,
      formFactor: formFactor,
      isDefault: item['isDefault'] == true ||
          (fullId.isNotEmpty && fullId == defaultFullId),
    );
  }
}

typedef _EnumerateNative = Pointer<Utf16> Function();
typedef _EnumerateDart = Pointer<Utf16> Function();
typedef _FreeNative = Void Function(Pointer<Utf16>);
typedef _FreeDart = void Function(Pointer<Utf16>);
