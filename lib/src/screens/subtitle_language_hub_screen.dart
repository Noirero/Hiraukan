import 'package:flutter/material.dart';

import '../services/subtitle_language_settings.dart';
import '../widgets/settings_section.dart';
import 'ai_features_screen.dart';
import 'llm_settings_screen.dart';
import 'online_translation_settings_screen.dart';
import 'player_lyric_style_screen.dart';
import 'preferences_screen.dart';
import 'subtitle_library_screen.dart';
import 'translation_glossary_screen.dart';

/// User-facing entry point for subtitle, language, translation, and local-AI
/// workflows. Existing screens remain the state/configuration owners.
class SubtitleLanguageHubScreen extends StatefulWidget {
  const SubtitleLanguageHubScreen({super.key});

  @override
  State<SubtitleLanguageHubScreen> createState() =>
      _SubtitleLanguageHubScreenState();
}

class _SubtitleLanguageHubScreenState extends State<SubtitleLanguageHubScreen> {
  final SubtitleLanguageSettings _languages = SubtitleLanguageSettings.instance;

  Future<void> _push(Widget screen) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final copy = _Copy.of(context);
    final source = SubtitleLanguageSettings.labelFor(_languages.sourceLanguage);
    final target = SubtitleLanguageSettings.labelFor(_languages.targetLanguage);

    return SettingsSubpageScaffold(
      title: copy.title,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          SettingsInfoCard(
            icon: Icons.subtitles_outlined,
            title: copy.introTitle,
            child: Text(
              copy.introSubtitle(source, target),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.45,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          const SizedBox(height: 18),
          _SectionLabel(title: copy.subtitleSection),
          SettingsSectionList(
            children: [
              SettingsNavigationTile(
                icon: Icons.library_books_outlined,
                title: copy.library,
                subtitle: copy.librarySubtitle,
                onTap: () => _push(const SubtitleLibraryScreen()),
              ),
              SettingsNavigationTile(
                icon: Icons.format_size_rounded,
                title: copy.playerStyle,
                subtitle: copy.playerStyleSubtitle,
                onTap: () => _push(const PlayerLyricStyleScreen()),
              ),
              SettingsNavigationTile(
                icon: Icons.tune_rounded,
                title: copy.subtitlePreferences,
                subtitle: copy.subtitlePreferencesSubtitle,
                onTap: () => _push(const PreferencesScreen()),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SectionLabel(title: copy.languageSection),
          SettingsSectionList(
            children: [
              SettingsNavigationTile(
                icon: Icons.translate_rounded,
                title: copy.onlineTranslation,
                subtitle: copy.onlineTranslationSubtitle(source, target),
                onTap: () => _push(const OnlineTranslationSettingsScreen()),
              ),
              SettingsNavigationTile(
                icon: Icons.menu_book_outlined,
                title: copy.glossary,
                subtitle: copy.glossarySubtitle,
                onTap: () => _push(const TranslationGlossaryScreen()),
              ),
              SettingsNavigationTile(
                icon: Icons.hub_outlined,
                title: copy.llm,
                subtitle: copy.llmSubtitle,
                onTap: () => _push(const LLMSettingsScreen()),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SectionLabel(
            title: copy.localAiSection,
            subtitle: copy.localAiSectionSubtitle,
          ),
          SettingsSectionList(
            children: [
              SettingsNavigationTile(
                icon: Icons.graphic_eq_rounded,
                title: copy.localTranscription,
                subtitle: copy.localTranscriptionSubtitle,
                onTap: () => _push(const AiFeaturesScreen()),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              copy.footer,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Copy {
  const _Copy({
    required this.title,
    required this.introTitle,
    required this.introSubtitle,
    required this.subtitleSection,
    required this.library,
    required this.librarySubtitle,
    required this.playerStyle,
    required this.playerStyleSubtitle,
    required this.subtitlePreferences,
    required this.subtitlePreferencesSubtitle,
    required this.languageSection,
    required this.onlineTranslation,
    required this.onlineTranslationSubtitle,
    required this.glossary,
    required this.glossarySubtitle,
    required this.llm,
    required this.llmSubtitle,
    required this.localAiSection,
    required this.localAiSectionSubtitle,
    required this.localTranscription,
    required this.localTranscriptionSubtitle,
    required this.footer,
  });

  final String title;
  final String introTitle;
  final String Function(String source, String target) introSubtitle;
  final String subtitleSection;
  final String library;
  final String librarySubtitle;
  final String playerStyle;
  final String playerStyleSubtitle;
  final String subtitlePreferences;
  final String subtitlePreferencesSubtitle;
  final String languageSection;
  final String onlineTranslation;
  final String Function(String source, String target) onlineTranslationSubtitle;
  final String glossary;
  final String glossarySubtitle;
  final String llm;
  final String llmSubtitle;
  final String localAiSection;
  final String localAiSectionSubtitle;
  final String localTranscription;
  final String localTranscriptionSubtitle;
  final String footer;

  static _Copy of(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;
    if (languageCode == 'id') {
      return _Copy(
        title: 'Subtitle & Bahasa',
        introTitle: 'Satu tempat untuk alur subtitle',
        introSubtitle: (source, target) =>
            'Pipeline saat ini: $source → $target. Subtitle sumber, lokal, dan cache tetap diprioritaskan sebelum fallback transkripsi atau terjemahan.',
        subtitleSection: 'Subtitle',
        library: 'Perpustakaan Subtitle',
        librarySubtitle: 'Kelola subtitle lokal, cache, folder, dan file yang sudah dibuat.',
        playerStyle: 'Tampilan Subtitle Player',
        playerStyleSubtitle: 'Atur ukuran teks dan tampilan subtitle di mini player dan full player.',
        subtitlePreferences: 'Preferensi Subtitle & Pemutaran',
        subtitlePreferencesSubtitle: 'Prioritas library, sumber terjemahan, auto-save, dan perilaku playback.',
        languageSection: 'Bahasa & Terjemahan',
        onlineTranslation: 'Bahasa & Terjemahan Online',
        onlineTranslationSubtitle: (source, target) =>
            '$source → $target · engine online, konteks, cache, dan fallback ASR.',
        glossary: 'Glossary Terjemahan',
        glossarySubtitle: 'Pertahankan nama, panggilan, honorific, dan istilah khusus secara konsisten.',
        llm: 'Provider LLM',
        llmSubtitle: 'Konfigurasi endpoint, API key, dan model jika memilih terjemahan berbasis LLM.',
        localAiSection: 'AI Lokal',
        localAiSectionSubtitle: 'Opsional dan terpisah dari penggunaan subtitle biasa.',
        localTranscription: 'Transkripsi Lokal (Whisper)',
        localTranscriptionSubtitle: 'Unduh/import model, aktifkan fallback otomatis, dan tuning performa Whisper.',
        footer:
            'Benchmark ASR dan eksperimen teknis tetap berada di Labs & Diagnostik, bukan di alur subtitle normal.',
      );
    }

    return _Copy(
      title: 'Subtitles & Language',
      introTitle: 'One place for the subtitle workflow',
      introSubtitle: (source, target) =>
          'Current pipeline: $source → $target. Source, local, and cached subtitles stay ahead of transcription or translation fallbacks.',
      subtitleSection: 'Subtitles',
      library: 'Subtitle Library',
      librarySubtitle: 'Manage local, cached, generated, and imported subtitle files.',
      playerStyle: 'Player Subtitle Style',
      playerStyleSubtitle: 'Adjust subtitle typography in the mini player and full player.',
      subtitlePreferences: 'Subtitle & Playback Preferences',
      subtitlePreferencesSubtitle: 'Library priority, translation source, auto-save, and playback behavior.',
      languageSection: 'Language & Translation',
      onlineTranslation: 'Online Language & Translation',
      onlineTranslationSubtitle: (source, target) =>
          '$source → $target · online engine, context, cache, and ASR fallback.',
      glossary: 'Translation Glossary',
      glossarySubtitle: 'Keep names, honorifics, places, and custom terms consistent.',
      llm: 'LLM Provider',
      llmSubtitle: 'Configure endpoint, API key, and model when using LLM translation.',
      localAiSection: 'Local AI',
      localAiSectionSubtitle: 'Optional and separate from the normal subtitle path.',
      localTranscription: 'Local Transcription (Whisper)',
      localTranscriptionSubtitle: 'Download/import models, enable fallback, and tune Whisper performance.',
      footer:
          'ASR benchmarks and technical experiments remain under Labs & Diagnostics instead of the normal subtitle workflow.',
    );
  }
}
