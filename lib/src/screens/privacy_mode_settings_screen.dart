import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'app_lock_settings_screen.dart';
import 'kikoflu_features_settings_screen.dart';
import '../providers/settings_provider.dart';
import '../services/app_lock_service.dart';
import '../utils/snackbar_util.dart';
import '../widgets/settings_section.dart';
import '../widgets/common_input_dialog.dart';

/// 防社死设置页面
class PrivacyModeSettingsScreen extends ConsumerStatefulWidget {
  const PrivacyModeSettingsScreen({super.key});

  @override
  ConsumerState<PrivacyModeSettingsScreen> createState() =>
      _PrivacyModeSettingsScreenState();
}

class _PrivacyModeSettingsScreenState
    extends ConsumerState<PrivacyModeSettingsScreen> {
  Future<void> _showEditTitleDialog() async {
    final settings = ref.read(privacyModeSettingsProvider);

    final title = await showCommonTextInputDialog(
      context,
      title: S.of(context).setReplaceTitle,
      labelText: S.of(context).replaceTitle,
      hintText: S.of(context).enterDisplayTitle,
      confirmLabel: S.of(context).save,
      initialValue: settings.customTitle,
      maxLength: 50,
      icon: Icons.title,
      validator: (value) =>
          value.isEmpty ? S.of(context).enterDisplayTitle : null,
    );

    final normalizedTitle = title?.trim();
    if (!mounted || normalizedTitle == null || normalizedTitle.isEmpty) return;

    ref
        .read(privacyModeSettingsProvider.notifier)
        .setCustomTitle(normalizedTitle);
    SnackBarUtil.showSuccess(context, S.of(context).replaceTitleSaved);
  }

  Future<void> _resetToDefault() async {
    await confirmAndRestoreSettingsDefaults(
      context: context,
      restore: ref.read(privacyModeSettingsProvider.notifier).resetToDefault,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(privacyModeSettingsProvider);
    final appLockEnabled = AppLockService.instance.isEnabled;

    return SettingsSubpageScaffold(
      title: S.of(context).privacyModeSettingsTitle,
      onRestoreDefaults: _resetToDefault,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SettingsSectionCard(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.privacy_tip_outlined,
                    color: Theme.of(context).colorScheme.primary,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          S.of(context).whatIsPrivacyMode,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          S.of(context).privacyModeDescription,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SettingsSectionCard(
            child: SettingsSwitchTile(
              icon: settings.enabled ? Icons.shield : Icons.shield_outlined,
              iconColor: settings.enabled
                  ? Colors.green
                  : Theme.of(context).colorScheme.primary,
              title: S.of(context).enablePrivacyMode,
              subtitle: settings.enabled
                  ? S.of(context).privacyModeEnabledSubtitle
                  : S.of(context).privacyModeDisabledSubtitle,
              value: settings.enabled,
              onChanged: (value) {
                ref
                    .read(privacyModeSettingsProvider.notifier)
                    .setEnabled(value);
              },
            ),
          ),
          const SizedBox(height: 16),
          SettingsSectionCard(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.settings,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        S.of(context).blurOptions,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
                SettingsSwitchTile(
                  icon: Icons.notifications_outlined,
                  title: S.of(context).blurNotificationCover,
                  subtitle: S.of(context).blurNotificationCoverSubtitle,
                  value: settings.blurCover,
                  enabled: settings.enabled,
                  onChanged: (value) {
                    ref
                        .read(privacyModeSettingsProvider.notifier)
                        .setBlurCover(value);
                  },
                ),
                const SettingsDivider(),
                SettingsSwitchTile(
                  icon: Icons.blur_on,
                  title: S.of(context).blurInAppCover,
                  subtitle: S.of(context).blurInAppCoverSubtitle,
                  value: settings.blurCoverInApp,
                  enabled: settings.enabled,
                  onChanged: (value) {
                    ref
                        .read(privacyModeSettingsProvider.notifier)
                        .setBlurCoverInApp(value);
                  },
                ),
                const SettingsDivider(),
                SettingsSwitchTile(
                  icon: Icons.text_fields,
                  title: S.of(context).replaceTitle,
                  subtitle: S.of(context).replaceTitleSubtitle,
                  value: settings.maskTitle,
                  enabled: settings.enabled,
                  onChanged: (value) {
                    ref
                        .read(privacyModeSettingsProvider.notifier)
                        .setMaskTitle(value);
                  },
                ),
                const SettingsDivider(),
                SettingsListTile(
                  enabled: settings.enabled && settings.maskTitle,
                  icon: Icons.edit,
                  title: S.of(context).replaceTitleContent,
                  subtitle: settings.customTitle,
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: settings.enabled && settings.maskTitle
                      ? _showEditTitleDialog
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SettingsSectionCard(
            child: Column(
              children: [
                SettingsListTile(
                  icon: appLockEnabled
                      ? Icons.lock_rounded
                      : Icons.lock_outline_rounded,
                  iconColor: appLockEnabled
                      ? Colors.green
                      : Theme.of(context).colorScheme.primary,
                  title: 'App Lock',
                  subtitle: appLockEnabled
                      ? 'Aktif — lindungi Hiraukan dengan PIN/biometrik'
                      : 'Kunci Hiraukan dengan PIN dan biometrik perangkat',
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const AppLockSettingsScreen(),
                      ),
                    );
                    if (mounted) setState(() {});
                  },
                ),
                const SettingsDivider(),
                SettingsListTile(
                  icon: Icons.auto_awesome_rounded,
                  title: 'Advanced Audio & AI',
                  subtitle:
                      'WAV conversion, Whisper, notifications, dan status Hi-Res',
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            const KikoFluFeaturesSettingsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SettingsSectionCard(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.preview,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        S.of(context).effectExample,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/icons/privacy_protection_sample.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
