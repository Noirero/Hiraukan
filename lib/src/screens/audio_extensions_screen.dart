import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../extensions/audio_extension.dart';
import '../extensions/audio_extension_provider.dart';
import '../extensions/miyorare_audio_pack.dart';
import '../services/miyorare_audio_catalog_service.dart';
import '../widgets/scrollable_appbar.dart';

class AudioExtensionsScreen extends ConsumerWidget {
  const AudioExtensionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundled = ref.watch(bundledAudioExtensionsProvider);
    final installState = ref.watch(audioExtensionInstallProvider);
    final catalog = ref.watch(miyorareAudioCatalogProvider);

    final bundledById = {
      for (final extension in bundled) extension.manifest.id: extension,
    };
    final snapshot = catalog.valueOrNull;
    final entries = snapshot?.pack.extensions ??
        bundled
            .map(
              (extension) => MiyorareAudioPackEntry(
                manifest: extension.manifest,
                deliveryKind: 'builtin',
                runtimeId: extension.manifest.id,
              ),
            )
            .toList(growable: false);

    return Scaffold(
      appBar: ScrollableAppBar(
        title: const Text('Audio Extensions'),
        actions: [
          IconButton(
            tooltip: 'Refresh Miyorare Pack',
            onPressed: () => ref.invalidate(miyorareAudioCatalogProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _CatalogStatusCard(
            catalog: catalog,
            snapshot: snapshot,
          ),
          const SizedBox(height: 12),
          for (final entry in entries) ...[
            _ExtensionTile(
              entry: entry,
              runtime: bundledById[entry.runtimeId],
              installed: installState.isInstalled(entry.runtimeId),
              onChanged: bundledById[entry.runtimeId] == null
                  ? null
                  : (enabled) async {
                      final controller =
                          ref.read(audioExtensionInstallProvider.notifier);
                      try {
                        if (enabled) {
                          await controller.install(entry);
                        } else {
                          await controller.remove(entry.runtimeId);
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

class _CatalogStatusCard extends StatelessWidget {
  const _CatalogStatusCard({
    required this.catalog,
    required this.snapshot,
  });

  final AsyncValue<MiyorareAudioCatalogSnapshot?> catalog;
  final MiyorareAudioCatalogSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    String title;
    String description;
    IconData icon;

    if (catalog.isLoading && snapshot == null) {
      title = 'Checking Miyorare Audio Pack';
      description =
          'Verifying the latest sealed catalog from Miyorare Source Packs.';
      icon = Icons.sync;
    } else if (snapshot == null) {
      title = 'Built-in audio catalog';
      description =
          'The latest stable Source Pack release does not provide a sealed '
          'audio catalog yet. Hiraukan is using its bundled source runtimes.';
      icon = Icons.inventory_2_outlined;
    } else if (snapshot!.fromCache) {
      title = 'Miyorare Audio Pack · last-known-good';
      description =
          snapshot!.releaseTag + ' · cached catalog passed SHA-256 validation.';
      icon = Icons.verified_outlined;
    } else {
      title = 'Miyorare Audio Pack · verified';
      description = snapshot!.releaseTag +
          ' · catalog matches the sealed release lock and SHA-256 digest.';
      icon = Icons.verified;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtensionTile extends StatelessWidget {
  const _ExtensionTile({
    required this.entry,
    required this.runtime,
    required this.installed,
    required this.onChanged,
  });

  final MiyorareAudioPackEntry entry;
  final AudioExtension? runtime;
  final bool installed;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final manifest = entry.manifest;
    final capabilities = manifest.capabilities.map((value) => value.name).toList()
      ..sort();
    final available = runtime != null;

    return Card(
      child: SwitchListTile(
        value: available && installed,
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
              'v' +
                  manifest.version +
                  ' · Auth: ' +
                  manifest.auth.wireValue +
                  ' · ' +
                  capabilities.join(', '),
            ),
            if (!available) ...[
              const SizedBox(height: 4),
              Text(
                'Runtime belum tersedia di versi Hiraukan ini. '
                'Perbarui aplikasi untuk memasangnya.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
