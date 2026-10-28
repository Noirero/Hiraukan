import 'dart:io';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'about_screen.dart';
import 'account_management_screen.dart';
import 'ai_features_screen.dart';
import 'app_lock_settings_screen.dart';
import 'audio_extensions_screen.dart';
import 'download_path_settings_screen.dart';
import 'log_screen.dart';
import 'permissions_screen.dart';
import 'preferences_screen.dart';
import 'privacy_mode_settings_screen.dart';
import 'settings_screen.dart';
import 'theme_settings_screen.dart';
import 'ui_settings_screen.dart';

/// The user-facing settings information architecture.
///
/// Existing settings screens remain the implementation source of truth. This
/// hub only changes how they are grouped and discovered so advanced/legacy
/// controls no longer compete with core product settings.
class SettingsHubScreen extends StatelessWidget {
  const SettingsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final copy = _SettingsHubCopy.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context).settingsTitle),
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          _IntroCard(copy: copy),
          const SizedBox(height: 18),
          _Section(
            title: copy.sources,
            subtitle: copy.sourcesSubtitle,
            children: [
              _DestinationTile(
                icon: Icons.extension_outlined,
                title: copy.audioSources,
                subtitle: copy.audioSourcesSubtitle,
                onTap: () => _push(context, const AudioExtensionsScreen()),
              ),
              _DestinationTile(
                icon: Icons.manage_accounts_outlined,
                title: S.of(context).accountManagement,
                subtitle: S.of(context).accountManagementSubtitle,
                onTap: () => _push(context, const AccountManagementScreen()),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: copy.playbackAndLanguage,
            subtitle: copy.playbackAndLanguageSubtitle,
            children: [
              _DestinationTile(
                icon: Icons.tune_rounded,
                title: S.of(context).preferenceSettings,
                subtitle: copy.playbackPreferencesSubtitle,
                onTap: () => _push(context, const PreferencesScreen()),
              ),
              _DestinationTile(
                icon: Icons.subtitles_outlined,
                title: copy.subtitlesAndAi,
                subtitle: copy.subtitlesAndAiSubtitle,
                onTap: () => _push(context, const AiFeaturesScreen()),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: copy.downloadsAndStorage,
            subtitle: copy.downloadsAndStorageSubtitle,
            children: [
              _DestinationTile(
                icon: Icons.folder_outlined,
                title: S.of(context).downloadPath,
                subtitle: S.of(context).downloadPathSubtitle,
                onTap: () => _push(context, const DownloadPathSettingsScreen()),
              ),
              _DestinationTile(
                icon: Icons.storage_outlined,
                title: S.of(context).cacheManagement,
                subtitle: copy.cacheSubtitle,
                onTap: () => _push(context, const SettingsScreen()),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: copy.privacyAndSecurity,
            subtitle: copy.privacyAndSecuritySubtitle,
            children: [
              _DestinationTile(
                icon: Icons.privacy_tip_outlined,
                title: S.of(context).privacyMode,
                subtitle: copy.privacySubtitle,
                onTap: () => _push(context, const PrivacyModeSettingsScreen()),
              ),
              _DestinationTile(
                icon: Icons.lock_outline_rounded,
                title: copy.appLock,
                subtitle: copy.appLockSubtitle,
                onTap: () => _push(context, const AppLockSettingsScreen()),
              ),
              if (Platform.isAndroid)
                _DestinationTile(
                  icon: Icons.security_outlined,
                  title: S.of(context).permissionManagement,
                  subtitle: S.of(context).permissionManagementSubtitle,
                  onTap: () => _push(context, const PermissionsScreen()),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: copy.appearance,
            subtitle: copy.appearanceSubtitle,
            children: [
              _DestinationTile(
                icon: Icons.palette_outlined,
                title: S.of(context).themeSettings,
                subtitle: S.of(context).themeSettingsSubtitle,
                onTap: () => _push(context, const ThemeSettingsScreen()),
              ),
              _DestinationTile(
                icon: Icons.dashboard_customize_outlined,
                title: S.of(context).uiSettings,
                subtitle: S.of(context).uiSettingsSubtitle,
                onTap: () => _push(context, const UiSettingsScreen()),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: copy.advanced,
            subtitle: copy.advancedSubtitle,
            muted: true,
            children: [
              _DestinationTile(
                icon: Icons.settings_suggest_outlined,
                title: copy.advancedSettings,
                subtitle: copy.advancedSettingsSubtitle,
                onTap: () => _push(context, const SettingsScreen()),
              ),
              _DestinationTile(
                icon: Icons.article_outlined,
                title: S.of(context).logTitle,
                subtitle: S.of(context).logSubtitle,
                onTap: () => _push(context, const LogScreen()),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: copy.about,
            children: [
              _DestinationTile(
                icon: Icons.info_outline_rounded,
                title: S.of(context).aboutTitle,
                subtitle: S.of(context).aboutSubtitle,
                onTap: () => _push(context, const AboutScreen()),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Hiraukan',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  static void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.copy});

  final _SettingsHubCopy copy;

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
    required this.children,
    this.subtitle,
    this.muted = false,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
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
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index != children.length - 1)
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
  const _DestinationTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

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
        child: Icon(icon, size: 21, color: scheme.primary),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        subtitle,
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
      onTap: onTap,
    );
  }
}

class _SettingsHubCopy {
  const _SettingsHubCopy({
    required this.introTitle,
    required this.introSubtitle,
    required this.sources,
    required this.sourcesSubtitle,
    required this.audioSources,
    required this.audioSourcesSubtitle,
    required this.playbackAndLanguage,
    required this.playbackAndLanguageSubtitle,
    required this.playbackPreferencesSubtitle,
    required this.subtitlesAndAi,
    required this.subtitlesAndAiSubtitle,
    required this.downloadsAndStorage,
    required this.downloadsAndStorageSubtitle,
    required this.cacheSubtitle,
    required this.privacyAndSecurity,
    required this.privacyAndSecuritySubtitle,
    required this.privacySubtitle,
    required this.appLock,
    required this.appLockSubtitle,
    required this.appearance,
    required this.appearanceSubtitle,
    required this.advanced,
    required this.advancedSubtitle,
    required this.advancedSettings,
    required this.advancedSettingsSubtitle,
    required this.about,
  });

  final String introTitle;
  final String introSubtitle;
  final String sources;
  final String sourcesSubtitle;
  final String audioSources;
  final String audioSourcesSubtitle;
  final String playbackAndLanguage;
  final String playbackAndLanguageSubtitle;
  final String playbackPreferencesSubtitle;
  final String subtitlesAndAi;
  final String subtitlesAndAiSubtitle;
  final String downloadsAndStorage;
  final String downloadsAndStorageSubtitle;
  final String cacheSubtitle;
  final String privacyAndSecurity;
  final String privacyAndSecuritySubtitle;
  final String privacySubtitle;
  final String appLock;
  final String appLockSubtitle;
  final String appearance;
  final String appearanceSubtitle;
  final String advanced;
  final String advancedSubtitle;
  final String advancedSettings;
  final String advancedSettingsSubtitle;
  final String about;

  static _SettingsHubCopy of(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final language = locale.languageCode;

    if (language == 'id') {
      return const _SettingsHubCopy(
        introTitle: 'Pengaturan yang lebih sederhana',
        introSubtitle:
            'Fitur utama dikelompokkan berdasarkan tujuan. Kontrol teknis tetap tersedia di bagian Lanjutan.',
        sources: 'Sumber & Akun',
        sourcesSubtitle: 'Kelola katalog dan identitas server yang digunakan Hiraukan.',
        audioSources: 'Sumber Audio',
        audioSourcesSubtitle: 'Aktifkan katalog audio yang ingin dipakai.',
        playbackAndLanguage: 'Pemutaran, Subtitle & Bahasa',
        playbackAndLanguageSubtitle: 'Atur perilaku dengar, subtitle, terjemahan, dan AI lokal.',
        playbackPreferencesSubtitle: 'Pemutaran, terjemahan, preload, dan perilaku aplikasi.',
        subtitlesAndAi: 'Subtitle & AI Lokal',
        subtitlesAndAiSubtitle: 'Whisper lokal, bahasa sumber/tujuan, dan subtitle otomatis.',
        downloadsAndStorage: 'Unduhan & Penyimpanan',
        downloadsAndStorageSubtitle: 'Lokasi file dan penggunaan penyimpanan.',
        cacheSubtitle: 'Buka pengaturan lama untuk pengelolaan cache lanjutan.',
        privacyAndSecurity: 'Privasi & Keamanan',
        privacyAndSecuritySubtitle: 'Lindungi tampilan, notifikasi, dan akses aplikasi.',
        privacySubtitle: 'Samarkan cover/judul dan atur perlindungan privasi.',
        appLock: 'Kunci Aplikasi',
        appLockSubtitle: 'Lindungi Hiraukan dengan PIN atau biometrik perangkat.',
        appearance: 'Tampilan',
        appearanceSubtitle: 'Tema, navigasi, player, kartu, dan kepadatan UI.',
        advanced: 'Lanjutan',
        advancedSubtitle: 'Kontrol teknis dan diagnostik untuk power user.',
        advancedSettings: 'Semua Pengaturan Lanjutan',
        advancedSettingsSubtitle: 'Akses pengaturan lengkap termasuk kontrol legacy dan teknis.',
        about: 'Tentang',
      );
    }

    return const _SettingsHubCopy(
      introTitle: 'Settings, without the clutter',
      introSubtitle:
          'Core controls are grouped by purpose. Technical and legacy controls remain available under Advanced.',
      sources: 'Sources & Accounts',
      sourcesSubtitle: 'Manage the catalogs and server identities Hiraukan uses.',
      audioSources: 'Audio Sources',
      audioSourcesSubtitle: 'Enable the audio catalogs you want to browse and search.',
      playbackAndLanguage: 'Playback, Subtitles & Language',
      playbackAndLanguageSubtitle: 'Listening behavior, subtitles, translation, and local AI.',
      playbackPreferencesSubtitle: 'Playback, translation, preload, and app behavior.',
      subtitlesAndAi: 'Subtitles & Local AI',
      subtitlesAndAiSubtitle: 'Local Whisper, source/target language, and subtitle fallback.',
      downloadsAndStorage: 'Downloads & Storage',
      downloadsAndStorageSubtitle: 'File location and storage usage.',
      cacheSubtitle: 'Open advanced settings for detailed cache management.',
      privacyAndSecurity: 'Privacy & Security',
      privacyAndSecuritySubtitle: 'Protect content presentation and access to the app.',
      privacySubtitle: 'Mask covers/titles and configure privacy protection.',
      appLock: 'App Lock',
      appLockSubtitle: 'Protect Hiraukan with a PIN or device biometrics.',
      appearance: 'Appearance',
      appearanceSubtitle: 'Theme, navigation, player, cards, and UI density.',
      advanced: 'Advanced',
      advancedSubtitle: 'Technical and diagnostic controls for power users.',
      advancedSettings: 'All Advanced Settings',
      advancedSettingsSubtitle: 'Access the complete legacy and technical settings surface.',
      about: 'About',
    );
  }
}
