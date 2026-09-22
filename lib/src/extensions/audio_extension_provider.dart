import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../services/kikoeru_api_service.dart';
import 'asmr_one_audio_extension.dart';
import 'audio_extension_registry.dart';

final audioExtensionRegistryProvider = Provider<AudioExtensionRegistry>((ref) {
  final api = ref.watch(kikoeruApiServiceProvider);
  final auth = ref.watch(authProvider);

  return AudioExtensionRegistry([
    AsmrOneAudioExtension(
      api: api,
      host: () => auth.host ?? KikoeruApiService.remoteHost,
      token: () => auth.token ?? '',
    ),
  ]);
});
