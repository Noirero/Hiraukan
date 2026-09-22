import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../extensions/audio_extension.dart';
import '../extensions/audio_extension_provider.dart';
import '../extensions/miyorare_audio_pack.dart';
import '../widgets/scrollable_appbar.dart';

class AudioExtensionsScreen extends ConsumerWidget {
  const AudioExtensionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundled = ref.watch(bundledAudioExtensionsProvider);
    final installState = ref.watch(audioExtensionInstallProvider);

    return Scaffold(
      appBar: const ScrollableAppBar(
        title: Text('Audio Extensions'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.inventory_2_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Miyorare Audio Pack v1',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Schema v1 uses built-in Hiraukan runtimes. '
                          'Installing enables a source; removing disables it '
                          'without downloading or executing unsigned code.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final extension in bundled) ...[
            _ExtensionTile(
              extension: extension,
              installed: installState.isInstalled(extension.manifest.id),
              onChanged: (enabled) async {
                final controller =
                    ref.read(audioExtensionInstallProvider.notifier);
                try {
                  if (enabled) {
                    await controller.install(
                      MiyorareAudioPackEntry(
                        manifest: extension.manifest,
                        deliveryKind: 'builtin',
                        runtimeId: extension.manifest.id,
                      ),
                    );
                  } else {
                    await controller.remove(extension.manifest.id);
                  }
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error.toString())),
                  );
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _ExtensionTile extends StatelessWidget {
  const _ExtensionTile({
    required this.extension,
    required this.installed,
    required this.onChanged,
  });

  final AudioExtension extension;
  final bool installed;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final manifest = extension.manifest;
    final capabilities = manifest.capabilities.map((value) => value.name).toList()
      ..sort();

    return Card(
      child: SwitchListTile(
        value: installed,
        onChanged: onChanged,
        secondary: Icon(
          manifest.capabilities.any((value) => value.name == 'playback')
              ? Icons.headphones
              : Icons.library_music_outlined,
        ),
        title: Text(manifest.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(manifest.id),
            const SizedBox(height: 4),
            Text(
              'Auth: ' +
                  manifest.auth.wireValue +
                  ' · ' +
                  capabilities.join(', '),
            ),
          ],
        ),
      ),
    );
  }
}
