import 'dart:io';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'about_screen.dart';
import 'account_management_screen.dart';
import 'ai_features_screen.dart';
import 'app_lock_settings_screen.dart';
import 'audio_extensions_screen.dart';
import 'download_path_settings_screen.dart';
import 'kikoflu_features_settings_screen.dart';
import 'log_screen.dart';
import 'permissions_screen.dart';
import 'preferences_screen.dart';
import 'privacy_mode_settings_screen.dart';
import 'settings_screen.dart';
import 'theme_settings_screen.dart';
import 'ui_settings_screen.dart';

/// User-facing settings information architecture.
///
/// Existing settings screens remain the implementation source of truth. This
/// hub changes discovery and hierarchy only: core controls stay prominent,
/// while legacy/experimental tooling is explicitly contained under Advanced.
class SettingsHubScreen extends StatelessWidget {
  const SettingsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = _Copy.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context).settingsTitle),
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          _IntroCard(copy: c),
          const SizedBox(height: 18),
          _Section(
            title: c.sources,
            subtitle: c.sourcesSubtitle,
            items: [
              _Item(
                Icons.extension_outlined,
                c.audioSources,
                c.audioSourcesSubtitle,
                () => _push(context, const AudioExtensionsScreen()),
              ),
              _Item(
                Icons.manage_accounts_outlined,
                S.of(context).accountManagement,
                S.of(context).accountManagementSubtitle,
                () => _push(context, const AccountManagementScreen()),
              ),
            ],
          ),
          _gap,
          _Section(
            title: c.playbackLanguage,
            subtitle: c.playbackLanguageSubtitle,
            items: [
              _Item(
                Icons.tune_rounded,
                S.of(context).preferenceSettings,
                c.playbackPreferencesSubtitle,
                () => _push(context, const PreferencesScreen()),
              ),
              _Item(
                Icons.subtitles_outlined,
                c.subtitlesAi,
                c.subtitlesAiSubtitle,
                () => _push(context, const AiFeaturesScreen()),
              ),
            ],
          ),
          _gap,
          _Section(
            title: c.downloadsStorage,
            subtitle: c.downloadsStorageSubtitle,
            items: [
              _Item(
                Icons.folder_outlined,
                S.of(context).downloadPath,
                S.of(context).downloadPathSubtitle,
                () => _push(context, const DownloadPathSettingsScreen()),
              ),
              _Item(
                Icons.storage_outlined,
                S.of(context).cacheManagement,
                c.cacheSubtitle,
                () => _push(context, const SettingsScreen()),
              ),
            ],
          ),
          _gap,
          _Section(
            title: c.privacySecurity,
            subtitle: c.privacySecuritySubtitle,
            items: [
              _Item(
                Icons.privacy_tip_outlined,
                S.of(context).privacyMode,
                c.privacySubtitle,
                () => _push(context, const PrivacyModeSettingsScreen()),
              ),
              _Item(
                Icons.lock_outline_rounded,
                c.appLock,
                c.appLockSubtitle,
                () => _push(context, const AppLockSettingsScreen()),
              ),
              if (Platform.isAndroid)
                _Item(
                  Icons.security_outlined,
                  S.of(context).permissionManagement,
                  S.of(context).permissionManagementSubtitle,
                  () => _push(context, const PermissionsScreen()),
                ),
            ],
          ),
          _gap,
          _Section(
            title: c.appearance,
            subtitle: c.appearanceSubtitle,
            items: [
              _Item(
                Icons.palette_outlined,
                S.of(context).themeSettings,
                S.of(context).themeSettingsSubtitle,
                () => _push(context, const ThemeSettingsScreen()),
              ),
              _Item(
                Icons.dashboard_customize_outlined,
                S.of(context).uiSettings,
                S.of(context).uiSettingsSubtitle,
                () => _push(context, const UiSettingsScreen()),
              ),
            ],
          ),
          _gap,
          _Section(
            title: c.advanced,
            subtitle: c.advancedSubtitle,
            muted: true,
            items: [
              _Item(
                Icons.settings_suggest_outlined,
                c.advancedSettings,
                c.advancedSettingsSubtitle,
                () => _push(context, const SettingsScreen()),
              ),
              _Item(
                Icons.science_outlined,
                c.labs,
                c.labsSubtitle,
                () => _push(context, const KikoFluFeaturesSettingsScreen()),
              ),
              _Item(
                Icons.article_outlined,
                S.of(context).logTitle,
                S.of(context).logSubtitle,
                () => _push(context, const LogScreen()),
              ),
            ],
          ),
          _gap,
          _Section(
            title: c.about,
            items: [
              _Item(
                Icons.info_outline_rounded,
                S.of(context).aboutTitle,
                S.of(context).aboutSubtitle,
                () => _push(context, const AboutScreen()),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              'Hiraukan',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  static const _gap = SizedBox(height: 16);

  static void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }
}

class _Item {
  const _Item(this.icon, this.title, this.subtitle, this.onTap);

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.copy});

  final _Copy copy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer.withValues(alpha: dark ? 0.42 : 0.68),
            scheme.surfaceContainerHigh,
          ],
        ),
        border: Border.all(
          color: scheme.primary.withValues(alpha: dark ? 0.22 : 0.14),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.tune_rounded, color: scheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy.introTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.25,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  copy.introSubtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
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

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.items,
    this.subtitle,
    this.muted = false,
  });

  final String title;
  final String? subtitle;
  final List<_Item> items;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: muted ? scheme.onSurfaceVariant : scheme.onSurface,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: muted
              ? scheme.surfaceContainerLow
              : scheme.surfaceContainerHigh.withValues(alpha: 0.72),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.34),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var index = 0; index < items.length; index++) ...[
                _DestinationTile(item: items[index]),
                if (index != items.length - 1)
                  Divider(
                    height: 1,
                    indent: 64,
                    color: scheme.outlineVariant.withValues(alpha: 0.45),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DestinationTile extends StatelessWidget {
  const _DestinationTile({required this.item});

  final _Item item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListTile(
      minVerticalPadding: 12,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(item.icon, size: 21, color: scheme.primary),
      ),
      title: Text(
        item.title,
        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        item.subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
          height: 1.35,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: scheme.onSurfaceVariant,
      ),
      onTap: item.onTap,
    );
  }
}

class _Copy {
  const _Copy({
    required this.introTitle,
    required this.introSubtitle,
    required this.sources,
    required this.sourcesSubtitle,
    required this.audioSources,
    required this.audioSourcesSubtitle,
    required this.playbackLanguage,
    required this.playbackLanguageSubtitle,
    required this.playbackPreferencesSubtitle,
    required this.subtitlesAi,
    required this.subtitlesAiSubtitle,
    required this.downloadsStorage,
    required this.downloadsStorageSubtitle,
    required this.cacheSubtitle,
    required this.privacySecurity,
    required this.privacySecuritySubtitle,
    required this.privacySubtitle,
    required this.appLock,
    required this.appLockSubtitle,
    required this.appearance,
    required this.appearanceSubtitle,
    required this.advanced,
    required this.advancedSubtitle,
    required this.advancedSettings,
    required this.advancedSettingsSubtitle,
    required this.labs,
    required this.labsSubtitle,
    required this.about,
  });

  final String introTitle;
  final String introSubtitle;
  final String sources;
  final String sourcesSubtitle;
  final String audioSources;
  final String audioSourcesSubtitle;
  final String playbackLanguage;
  final String playbackLanguageSubtitle;
  final String playbackPreferencesSubtitle;
  final String subtitlesAi;
  final String subtitlesAiSubtitle;
  final String downloadsStorage;
  final String downloadsStorageSubtitle;
  final String cacheSubtitle;
  final String privacySecurity;
  final String privacySecuritySubtitle;
  final String privacySubtitle;
  final String appLock;
  final String appLockSubtitle;
  final String appearance;
  final String appearanceSubtitle;
  final String advanced;
  final String advancedSubtitle;
  final String advancedSettings;
  final String advancedSettingsSubtitle;
  final String labs;
  final String labsSubtitle;
  final String about;

  static _Copy of(BuildContext context) {
    if (Localizations.localeOf(context).languageCode == 'id') {
      return const _Copy(
        introTitle: 'Pengaturan yang lebih sederhana',
        introSubtitle:
            'Fitur utama dikelompokkan berdasarkan tujuan. Kontrol teknis tetap tersedia di bagian Lanjutan.',
        sources: 'Sumber & Akun',
        sourcesSubtitle:
            'Kelola katalog dan identitas server yang digunakan Hiraukan.',
        audioSources: 'Sumber Audio',
        audioSourcesSubtitle: 'Aktifkan katalog audio yang ingin dipakai.',
        playbackLanguage: 'Pemutaran, Subtitle & Bahasa',
        playbackLanguageSubtitle:
            'Atur perilaku dengar, subtitle, terjemahan, dan AI lokal.',
        playbackPreferencesSubtitle:
            'Pemutaran, terjemahan, preload, dan perilaku aplikasi.',
        subtitlesAi: 'Subtitle & AI Lokal',
        subtitlesAiSubtitle:
            'Whisper lokal, bahasa sumber/tujuan, dan subtitle otomatis.',
        downloadsStorage: 'Unduhan & Penyimpanan',
        downloadsStorageSubtitle: 'Lokasi file dan penggunaan penyimpanan.',
        cacheSubtitle: 'Pengelolaan cache dan batas penyimpanan lanjutan.',
        privacySecurity: 'Privasi & Keamanan',
        privacySecuritySubtitle:
            'Lindungi tampilan, notifikasi, dan akses aplikasi.',
        privacySubtitle: 'Samarkan cover/judul dan atur perlindungan privasi.',
        appLock: 'Kunci Aplikasi',
        appLockSubtitle:
            'Lindungi Hiraukan dengan PIN atau biometrik perangkat.',
        appearance: 'Tampilan',
        appearanceSubtitle: 'Tema, navigasi, player, kartu, dan kepadatan UI.',
        advanced: 'Lanjutan',
        advancedSubtitle: 'Kontrol teknis dan diagnostik untuk power user.',
        advancedSettings: 'Semua Pengaturan Lanjutan',
        advancedSettingsSubtitle:
            'Akses pengaturan lengkap dan kontrol kompatibilitas lama.',
        labs: 'Labs & Diagnostik',
        labsSubtitle:
            'Benchmark ASR, batch transcription, Hi-Res probe, FCM, dan eksperimen audio.',
        about: 'Tentang',
      );
    }

    return const _Copy(
      introTitle: 'Settings, without the clutter',
      introSubtitle:
          'Core controls are grouped by purpose. Technical controls remain available under Advanced.',
      sources: 'Sources & Accounts',
      sourcesSubtitle: 'Manage the catalogs and server identities Hiraukan uses.',
      audioSources: 'Audio Sources',
      audioSourcesSubtitle:
          'Enable the audio catalogs you want to browse and search.',
      playbackLanguage: 'Playback, Subtitles & Language',
      playbackLanguageSubtitle:
          'Listening behavior, subtitles, translation, and local AI.',
      playbackPreferencesSubtitle:
          'Playback, translation, preload, and app behavior.',
      subtitlesAi: 'Subtitles & Local AI',
      subtitlesAiSubtitle:
          'Local Whisper, source/target language, and subtitle fallback.',
      downloadsStorage: 'Downloads & Storage',
      downloadsStorageSubtitle: 'File location and storage usage.',
      cacheSubtitle: 'Advanced cache and storage-limit management.',
      privacySecurity: 'Privacy & Security',
      privacySecuritySubtitle: 'Protect content presentation and app access.',
      privacySubtitle: 'Mask covers/titles and configure privacy protection.',
      appLock: 'App Lock',
      appLockSubtitle: 'Protect Hiraukan with a PIN or device biometrics.',
      appearance: 'Appearance',
      appearanceSubtitle: 'Theme, navigation, player, cards, and UI density.',
      advanced: 'Advanced',
      advancedSubtitle: 'Technical and diagnostic controls for power users.',
      advancedSettings: 'All Advanced Settings',
      advancedSettingsSubtitle:
          'Access the complete compatibility and legacy settings surface.',
      labs: 'Labs & Diagnostics',
      labsSubtitle:
          'ASR benchmarks, batch transcription, Hi-Res probes, FCM, and audio experiments.',
      about: 'About',
    );
  }
}
