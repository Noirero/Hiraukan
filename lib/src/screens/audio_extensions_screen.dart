import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../extensions/audio_extension.dart';
import '../extensions/audio_extension_manifest.dart';
import '../extensions/audio_extension_provider.dart';
import '../extensions/miyorare_audio_pack.dart';
import '../services/miyorare_audio_catalog_service.dart';
import '../widgets/scrollable_appbar.dart';

class AudioExtensionsScreen extends ConsumerWidget {
  const AudioExtensionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = _SourceCopy.of(context);
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
        title: Text(copy.title),
        actions: [
          IconButton(
            tooltip: copy.refresh,
            onPressed: () => ref.invalidate(miyorareAudioCatalogProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _SourceIntro(copy: copy),
          const SizedBox(height: 12),
          _CatalogStatusCard(
            catalog: catalog,
            snapshot: snapshot,
            copy: copy,
          ),
          const SizedBox(height: 18),
          Text(
            copy.availableSources,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            copy.availableSourcesSubtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 10),
          for (final entry in entries) ...[
            _ExtensionTile(
              entry: entry,
              runtime: bundledById[entry.runtimeId],
              installed: installState.isInstalled(entry.runtimeId),
              copy: copy,
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

class _SourceIntro extends StatelessWidget {
  const _SourceIntro({required this.copy});

  final _SourceCopy copy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.hub_outlined, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy.introTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  copy.introSubtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.42,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogStatusCard extends StatelessWidget {
  const _CatalogStatusCard({
    required this.catalog,
    required this.snapshot,
    required this.copy,
  });

  final AsyncValue<MiyorareAudioCatalogSnapshot?> catalog;
  final MiyorareAudioCatalogSnapshot? snapshot;
  final _SourceCopy copy;

  @override
  Widget build(BuildContext context) {
    late String title;
    late String description;
    late IconData icon;

    if (catalog.isLoading && snapshot == null) {
      title = copy.verifying;
      description = copy.verifyingSubtitle;
      icon = Icons.sync_rounded;
    } else if (snapshot == null) {
      title = copy.builtInCatalog;
      description = copy.builtInCatalogSubtitle;
      icon = Icons.inventory_2_outlined;
    } else if (snapshot!.fromCache) {
      title = copy.verifiedCached;
      description = copy.verifiedCachedSubtitle(snapshot!.releaseTag);
      icon = Icons.verified_outlined;
    } else {
      title = copy.verified;
      description = copy.verifiedSubtitle(snapshot!.releaseTag);
      icon = Icons.verified_rounded;
    }

    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.34),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.35,
                        ),
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
    required this.copy,
  });

  final MiyorareAudioPackEntry entry;
  final AudioExtension? runtime;
  final bool installed;
  final ValueChanged<bool>? onChanged;
  final _SourceCopy copy;

  @override
  Widget build(BuildContext context) {
    final manifest = entry.manifest;
    final available = runtime != null;
    final scheme = Theme.of(context).colorScheme;
    final capabilityLabels = _capabilityLabels(manifest.capabilities, copy);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.surfaceContainerHigh.withValues(alpha: 0.72),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.34),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SwitchListTile(
            value: available && installed,
            onChanged: onChanged,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            secondary: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                manifest.capabilities.contains(AudioExtensionCapability.playback)
                    ? Icons.headphones_rounded
                    : Icons.download_for_offline_outlined,
                color: scheme.primary,
              ),
            ),
            title: Text(
              manifest.name,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            subtitle: Text(
              !available
                  ? copy.runtimeUnavailable
                  : installed
                      ? copy.enabled
                      : copy.disabled,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: !available ? scheme.error : scheme.onSurfaceVariant,
                  ),
            ),
          ),
          if (capabilityLabels.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final capability in capabilityLabels)
                      _CapabilityChip(label: capability),
                  ],
                ),
              ),
            ),
          ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 14),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            title: Text(
              copy.details,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            children: [
              _TechnicalRow(label: copy.version, value: manifest.version),
              _TechnicalRow(label: copy.runtimeId, value: entry.runtimeId),
              _TechnicalRow(
                label: copy.authentication,
                value: _authLabel(manifest.auth, copy),
              ),
              if (manifest.languages.isNotEmpty)
                _TechnicalRow(
                  label: copy.languages,
                  value: manifest.languages.join(', '),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static List<String> _capabilityLabels(
    Set<AudioExtensionCapability> capabilities,
    _SourceCopy copy,
  ) {
    final labels = <String>[];
    if (capabilities.contains(AudioExtensionCapability.playback)) {
      labels.add(copy.play);
    }
    if (capabilities.contains(AudioExtensionCapability.download)) {
      labels.add(copy.download);
    }
    if (capabilities.contains(AudioExtensionCapability.subtitles)) {
      labels.add(copy.subtitles);
    }
    if (capabilities.contains(AudioExtensionCapability.search)) {
      labels.add(copy.search);
    }
    return labels;
  }

  static String _authLabel(
    AudioExtensionAuthRequirement auth,
    _SourceCopy copy,
  ) {
    return switch (auth) {
      AudioExtensionAuthRequirement.none => copy.authNone,
      AudioExtensionAuthRequirement.optional => copy.authOptional,
      AudioExtensionAuthRequirement.required => copy.authRequired,
    };
  }
}

class _CapabilityChip extends StatelessWidget {
  const _CapabilityChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _TechnicalRow extends StatelessWidget {
  const _TechnicalRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceCopy {
  const _SourceCopy({
    required this.title,
    required this.refresh,
    required this.introTitle,
    required this.introSubtitle,
    required this.availableSources,
    required this.availableSourcesSubtitle,
    required this.verifying,
    required this.verifyingSubtitle,
    required this.builtInCatalog,
    required this.builtInCatalogSubtitle,
    required this.verifiedCached,
    required this.verifiedCachedSubtitle,
    required this.verified,
    required this.verifiedSubtitle,
    required this.runtimeUnavailable,
    required this.enabled,
    required this.disabled,
    required this.details,
    required this.version,
    required this.runtimeId,
    required this.authentication,
    required this.languages,
    required this.play,
    required this.download,
    required this.subtitles,
    required this.search,
    required this.authNone,
    required this.authOptional,
    required this.authRequired,
  });

  final String title;
  final String refresh;
  final String introTitle;
  final String introSubtitle;
  final String availableSources;
  final String availableSourcesSubtitle;
  final String verifying;
  final String verifyingSubtitle;
  final String builtInCatalog;
  final String builtInCatalogSubtitle;
  final String verifiedCached;
  final String Function(String release) verifiedCachedSubtitle;
  final String verified;
  final String Function(String release) verifiedSubtitle;
  final String runtimeUnavailable;
  final String enabled;
  final String disabled;
  final String details;
  final String version;
  final String runtimeId;
  final String authentication;
  final String languages;
  final String play;
  final String download;
  final String subtitles;
  final String search;
  final String authNone;
  final String authOptional;
  final String authRequired;

  static _SourceCopy of(BuildContext context) {
    if (Localizations.localeOf(context).languageCode == 'id') {
      return _SourceCopy(
        title: 'Sumber Audio',
        refresh: 'Perbarui katalog sumber',
        introTitle: 'Pilih sumber yang ingin digunakan',
        introSubtitle:
            'Hiraukan menggabungkan sumber yang aktif ke dalam Home dan Pencarian. Matikan sumber yang tidak ingin digunakan.',
        availableSources: 'Sumber tersedia',
        availableSourcesSubtitle:
            'Kemampuan utama ditampilkan langsung; detail teknis tersedia bila diperlukan.',
        verifying: 'Memverifikasi katalog sumber',
        verifyingSubtitle:
            'Hiraukan sedang memeriksa katalog yang dipercaya sebelum digunakan.',
        builtInCatalog: 'Katalog bawaan',
        builtInCatalogSubtitle:
            'Katalog remote tervalidasi belum tersedia; Hiraukan memakai runtime bawaan aplikasi.',
        verifiedCached: 'Katalog tervalidasi · cache tepercaya',
        verifiedCachedSubtitle: (release) => '$release · verifikasi integritas berhasil.',
        verified: 'Katalog tervalidasi',
        verifiedSubtitle: (release) => '$release · sumber sesuai release lock yang dipercaya.',
        runtimeUnavailable: 'Belum tersedia pada versi Hiraukan ini.',
        enabled: 'Aktif di Home dan Pencarian',
        disabled: 'Tidak digunakan',
        details: 'Detail teknis',
        version: 'Versi',
        runtimeId: 'Runtime ID',
        authentication: 'Autentikasi',
        languages: 'Bahasa',
        play: 'Putar',
        download: 'Unduh',
        subtitles: 'Subtitle',
        search: 'Cari',
        authNone: 'Tidak diperlukan',
        authOptional: 'Opsional',
        authRequired: 'Diperlukan',
      );
    }

    return _SourceCopy(
      title: 'Audio Sources',
      refresh: 'Refresh source catalog',
      introTitle: 'Choose the sources you want to use',
      introSubtitle:
          'Hiraukan merges enabled sources into Home and Search. Disable any source you do not want to use.',
      availableSources: 'Available sources',
      availableSourcesSubtitle:
          'Core capabilities are shown first; technical details remain available when needed.',
      verifying: 'Verifying source catalog',
      verifyingSubtitle:
          'Hiraukan is checking the trusted catalog before using it.',
      builtInCatalog: 'Built-in catalog',
      builtInCatalogSubtitle:
          'A validated remote catalog is not available, so Hiraukan is using bundled source runtimes.',
      verifiedCached: 'Validated catalog · trusted cache',
      verifiedCachedSubtitle: (release) => '$release · integrity verification passed.',
      verified: 'Validated catalog',
      verifiedSubtitle: (release) => '$release · sources match the trusted release lock.',
      runtimeUnavailable: 'Not available in this Hiraukan version.',
      enabled: 'Enabled in Home and Search',
      disabled: 'Not in use',
      details: 'Technical details',
      version: 'Version',
      runtimeId: 'Runtime ID',
      authentication: 'Authentication',
      languages: 'Languages',
      play: 'Play',
      download: 'Download',
      subtitles: 'Subtitles',
      search: 'Search',
      authNone: 'Not required',
      authOptional: 'Optional',
      authRequired: 'Required',
    );
  }
}
