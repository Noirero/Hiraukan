/// `package:media_kit` bindings for `just_audio` to support Linux and Windows.
library just_audio_media_kit;

import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:just_audio_media_kit/mediakit_player.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:logging/logging.dart';
import 'package:media_kit/media_kit.dart';
import 'package:universal_platform/universal_platform.dart';

class JustAudioMediaKit extends JustAudioPlatform {
  JustAudioMediaKit();

  /// The internal MPV player's logLevel
  static MPVLogLevel mpvLogLevel = MPVLogLevel.error;

  /// Sets the demuxer's cache size (in bytes)
  static int bufferSize = 32 * 1024 * 1024;

  /// Sets the name of the underlying window & process for native backend. This is visible inside the Windows' volume mixer.
  static String title = 'JustAudioMediaKit';

  /// Sets the list of allowed protocols for native backend.
  static List<String> protocolWhitelist = const [
    'udp',
    'rtp',
    'tcp',
    'tls',
    'data',
    'file',
    'http',
    'https',
    'crypto',
  ];

  /// Enables or disables pitch shift control for native backend (with this set to false, [setPitch] won't work).
  ///
  /// This uses `scaletempo` under the hood & disables `audio-pitch-correction`.
  static bool pitch = true;

  /// Enables gapless playback via the [`--prefetch-playlist`](https://mpv.io/manual/stable/#options-prefetch-playlist) in libmpv
  ///
  /// This is highly experimental. Use at your own risk.
  ///
  /// Check mpv's docs and the related just_audio_media_kit issue for details.
  static bool prefetchPlaylist = false;

  static final _logger = Logger('JustAudioMediaKit');
  final _players = HashMap<String, MediaKitPlayer>();

  /// Players that are disposing (player id -> future that completes when the player is disposed)
  final _disposingPlayers = HashMap<String, Future<void>>();

  /// Hiraukan writes its normal mpv.conf immediately before this adapter is
  /// initialized. On Windows, overlay the optional selected WASAPI endpoint at
  /// this exact point so existing passthrough/proxy/video settings are kept.
  static void _applyHiraukanWindowsAudioSidecar() {
    if (!UniversalPlatform.isWindows) return;
    try {
      final exeDir = File(Platform.resolvedExecutable).parent;
      final separator = Platform.pathSeparator;
      final configDir = Directory('${exeDir.path}${separator}portable_config');
      final sidecar = File('${configDir.path}${separator}hiraukan_wasapi.json');
      if (!sidecar.existsSync()) return;
      final decoded = jsonDecode(sidecar.readAsStringSync());
      if (decoded is! Map || decoded['enabled'] != true) return;
      final deviceId = decoded['deviceId']?.toString().trim() ?? '';
      if (deviceId.isEmpty) return;

      final config = File('${configDir.path}${separator}mpv.conf');
      final original = config.existsSync() ? config.readAsStringSync() : '';
      final filtered = original
          .split('\n')
          .where((line) =>
              !line.startsWith('ao=') &&
              !line.startsWith('audio-exclusive=') &&
              !line.startsWith('audio-device='))
          .join('\n')
          .trimRight();
      final output = StringBuffer();
      if (filtered.isNotEmpty) output.writeln(filtered);
      output
        ..writeln('ao=wasapi')
        ..writeln('audio-exclusive=yes')
        ..writeln('audio-device=wasapi/$deviceId');
      config.writeAsStringSync(output.toString());
    } catch (error) {
      _logger.warning('Failed to apply Hiraukan WASAPI device: $error');
    }
  }

  /// Initializes the plugin if the platform we're running on is marked
  /// as true, otherwise it will leave everything unchanged.
  ///
  /// Can also be safely called from Web, even though it'll have no effect
  static void ensureInitialized({
    bool linux = true,
    bool windows = true,
    bool android = false,
    bool iOS = false,
    bool macOS = false,

    /// The path to the libmpv dynamic library.
    /// The name of the library is generally `libmpv.so` on GNU/Linux and `libmpv-2.dll` on Windows.
    String? libmpv,
  }) {
    if ((UniversalPlatform.isLinux && linux) ||
        (UniversalPlatform.isWindows && windows) ||
        (UniversalPlatform.isAndroid && android) ||
        (UniversalPlatform.isIOS && iOS) ||
        (UniversalPlatform.isMacOS && macOS)) {
      _applyHiraukanWindowsAudioSidecar();
      registerWith();
      MediaKit.ensureInitialized(libmpv: libmpv);
    }
  }

  /// Registers the plugin with [JustAudioPlatform]
  static void registerWith() {
    JustAudioPlatform.instance = JustAudioMediaKit();
  }

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    if (_players.containsKey(request.id)) {
      throw PlatformException(
          code: 'error', message: 'Player ${request.id} already exists!');
    }

    _logger.fine('instantiating new player ${request.id}');
    final player = MediaKitPlayer(request.id);
    _players[request.id] = player;
    await player.ready();
    _logger.fine('player ready! (players: $_players)');
    return player;
  }

  @override
  Future<DisposePlayerResponse> disposePlayer(
      DisposePlayerRequest request) async {
    _logger.fine('disposing player ${request.id}');

    // temporary workaround because disposePlayer is called more than once
    if (_disposingPlayers.containsKey(request.id)) {
      _logger.fine('disposePlayer() called more than once!');
      await _disposingPlayers[request.id]!;
      return DisposePlayerResponse();
    }

    if (!_players.containsKey(request.id)) {
      throw PlatformException(
          code: 'error', message: 'Player ${request.id} doesn\'t exist.');
    }

    final future = _players[request.id]!.release();
    _players.remove(request.id);
    _disposingPlayers[request.id] = future;
    await future;
    _disposingPlayers.remove(request.id);

    return DisposePlayerResponse();
  }

  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(
      DisposeAllPlayersRequest request) async {
    _logger.fine('disposing of all players...');
    if (_players.isNotEmpty) {
      await Future.wait(_players.values.map((e) => e.release()));
      _players.clear();
    }
    return DisposeAllPlayersResponse();
  }
}
