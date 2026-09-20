import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/lyric.dart';
import '../../providers/audio_provider.dart';
import '../../providers/lyric_provider.dart';
import '../../providers/subtitle_controller_provider.dart';
import '../../providers/player_lyric_style_provider.dart';
import '../../subtitles/subtitle_controller.dart';
import '../../../l10n/app_localizations.dart';

/// 小字幕显示组件（在封面下方显示当前字幕）
class LyricDisplay extends ConsumerWidget {
  final String? albumName;

  const LyricDisplay({super.key, this.albumName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitleState = ref.watch(subtitleControllerProvider);
    final lyricState = ref.watch(lyricControllerProvider);
    final position = ref.watch(positionProvider);
    final lyricSettings = ref.watch(playerLyricSettingsProvider);

    if (lyricState.lyrics.isNotEmpty &&
        subtitleState.displayMode != SubtitleDisplayMode.off) {
      final originalLyrics = lyricState.adjustedLyrics;
      final translatedLyrics = lyricState.translatedLyrics == null
          ? null
          : lyricState.translatedLyrics!
              .map((line) => line.applyOffset(lyricState.timelineOffset))
              .toList(growable: false);

      final currentTexts = position.when(
        data: (pos) {
          final original =
              LyricParser.getCurrentLyric(originalLyrics, pos) ?? '♪';
          final translated = translatedLyrics == null
              ? null
              : LyricParser.getCurrentLyric(translatedLyrics, pos);
          return (original: original, translated: translated);
        },
        loading: () => (original: '♪', translated: null),
        error: (_, __) => (original: '♪', translated: null),
      );

      final primaryText = switch (subtitleState.displayMode) {
        SubtitleDisplayMode.translated =>
          currentTexts.translated ?? currentTexts.original,
        _ => currentTexts.original,
      };
      final secondaryText =
          subtitleState.displayMode == SubtitleDisplayMode.bilingual &&
                  currentTexts.translated != null &&
                  currentTexts.translated != currentTexts.original
              ? currentTexts.translated
              : null;

      return AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: Container(
          constraints: const BoxConstraints(minHeight: 23),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  primaryText,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        height: lyricSettings.smallLineHeight,
                        fontSize: lyricSettings.smallFontSize,
                      ),
                  textAlign: TextAlign.center,
                ),
                if (secondaryText != null)
                  Text(
                    secondaryText,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                          height: lyricSettings.smallLineHeight,
                        ),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        ),
      );
    }

    if (lyricState.isGeneratingSubtitle ||
        lyricState.subtitleGenerationStatus != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (lyricState.isGeneratingSubtitle) ...[
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                lyricState.subtitleGenerationStatus ??
                    'Membuat subtitle Jepang…',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    if (albumName != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        child: Text(
          albumName!,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

/// 全屏字幕显示组件（横屏或竖屏全屏模式）
class FullLyricDisplay extends ConsumerStatefulWidget {
  final Duration? seekingPosition;
  final bool isPortrait;
  final bool isLocked;
  final VoidCallback? onLongPress;

  const FullLyricDisplay({
    super.key,
    this.seekingPosition,
    this.isPortrait = false,
    this.isLocked = false,
    this.onLongPress,
  });

  @override
  ConsumerState<FullLyricDisplay> createState() => _FullLyricDisplayState();
}

class _FullLyricDisplayState extends ConsumerState<FullLyricDisplay> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _itemKeys = {};
  int? _currentLyricIndex;
  bool _autoScroll = true;

  @override
  void dispose() {
    _scrollController.dispose();
    _itemKeys.clear();
    super.dispose();
  }

  GlobalKey _getKeyForIndex(int index) {
    if (!_itemKeys.containsKey(index)) {
      _itemKeys[index] = GlobalKey();
    }
    return _itemKeys[index]!;
  }

  int _getCurrentLyricIndex(Duration position, List<LyricLine> lyrics) {
    for (int i = lyrics.length - 1; i >= 0; i--) {
      if (position >= lyrics[i].startTime) {
        return i;
      }
    }
    return -1;
  }

  /// 估算单个字幕 item 的高度
  double _estimateItemHeight(String text, BuildContext context, bool isActive) {
    final lyricSettings = ref.read(playerLyricSettingsProvider);
    const double verticalPadding = 24.0;
    const double verticalMargin = 8.0;
    final double lineHeight = lyricSettings.fullLineHeight;
    final double fontSize = isActive
        ? lyricSettings.fullActiveFontSize
        : lyricSettings.fullInactiveFontSize;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final double lyricAreaWidth;
    final double outerPadding;

    if (widget.isPortrait) {
      lyricAreaWidth = screenWidth;
      outerPadding = 48.0;
    } else {
      lyricAreaWidth = screenWidth * 0.6;
      outerPadding = 0.0;
    }

    const double listViewPadding = 48.0;
    const double containerHorizontalPadding = 32.0;
    final availableTextWidth = lyricAreaWidth -
        outerPadding -
        listViewPadding -
        containerHorizontalPadding;

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          height: lineHeight,
        ),
      ),
      maxLines: null,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout(maxWidth: availableTextWidth);
    final textHeight = textPainter.height;

    return verticalPadding + textHeight + verticalMargin;
  }

  ({String primary, String? secondary}) _textsForIndex(
    int index,
    LyricState lyricState,
    SubtitleDisplayMode mode,
  ) {
    final original = lyricState.adjustedLyrics[index].text;
    final translatedSource = lyricState.translatedLyrics;
    final translated = translatedSource != null && index < translatedSource.length
        ? translatedSource[index].text
        : null;

    return switch (mode) {
      SubtitleDisplayMode.translated => (
          primary: translated ?? original,
          secondary: null,
        ),
      SubtitleDisplayMode.bilingual => (
          primary: original,
          secondary: translated != null && translated != original
              ? translated
              : null,
        ),
      _ => (primary: original, secondary: null),
    };
  }

  /// Estimate the fallback scroll offset using the actual selected display mode.
  double _calculateOffsetToIndex(
    int targetIndex,
    LyricState lyricState,
    SubtitleDisplayMode mode,
    BuildContext context,
  ) {
    double offset = 20.0;
    final lyrics = lyricState.adjustedLyrics;

    for (int i = 0; i < targetIndex && i < lyrics.length; i++) {
      final texts = _textsForIndex(i, lyricState, mode);
      final combined = texts.secondary == null
          ? texts.primary
          : '${texts.primary}\n${texts.secondary}';
      offset += _estimateItemHeight(combined, context, false);
    }

    return offset;
  }

  void _scrollToLyric(int index, {bool animate = true, bool force = false}) {
    if (!_autoScroll || !_scrollController.hasClients) return;

    final key = _getKeyForIndex(index);
    final itemContext = key.currentContext;

    if (itemContext != null) {
      Scrollable.ensureVisible(
        itemContext,
        alignment: 0.5,
        duration: animate ? const Duration(milliseconds: 300) : Duration.zero,
        curve: Curves.easeOut,
      );
    } else if (force && mounted) {
      final lyricState = ref.read(lyricControllerProvider);
      final mode = ref.read(subtitleControllerProvider).displayMode;
      final targetOffset =
          _calculateOffsetToIndex(index, lyricState, mode, context);
      final maxScroll = _scrollController.position.maxScrollExtent;
      final clampedOffset = targetOffset.clamp(0.0, maxScroll);

      _scrollController.jumpTo(clampedOffset);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final newContext = key.currentContext;
        if (newContext != null && mounted) {
          Scrollable.ensureVisible(
            newContext,
            alignment: 0.5,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _onLyricTap(int index) {
    final lyricState = ref.read(lyricControllerProvider);
    final originalLyrics = lyricState.adjustedLyrics;
    if (index >= 0 && index < originalLyrics.length) {
      final targetTime = originalLyrics[index].startTime;
      ref
          .read(audioPlayerControllerProvider.notifier)
          .seekAndPersist(targetTime);

      setState(() {
        _autoScroll = false;
      });

      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _autoScroll = true;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lyricState = ref.watch(lyricControllerProvider);
    final subtitleState = ref.watch(subtitleControllerProvider);
    final position = ref.watch(positionProvider);
    final lyricSettings = ref.watch(playerLyricSettingsProvider);

    if (subtitleState.displayMode == SubtitleDisplayMode.off) {
      return const SizedBox.shrink();
    }

    return position.when(
      data: (pos) {
        final originalLyrics = lyricState.adjustedLyrics;
        final displayPosition = widget.seekingPosition ?? pos;
        final currentIndex =
            _getCurrentLyricIndex(displayPosition, originalLyrics);

        if (currentIndex != _currentLyricIndex && currentIndex >= 0) {
          final previousIndex = _currentLyricIndex;
          _currentLyricIndex = currentIndex;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final isLargeJump = previousIndex == null ||
                (currentIndex - previousIndex).abs() > 5;
            final animate = widget.seekingPosition == null;

            _scrollToLyric(currentIndex, animate: animate, force: isLargeJump);
          });
        }

        return GestureDetector(
          onLongPress: widget.onLongPress,
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            itemCount: originalLyrics.length,
            itemBuilder: (context, index) {
              final texts = _textsForIndex(
                index,
                lyricState,
                subtitleState.displayMode,
              );
              final isActive = index == currentIndex;
              final isPast = index < currentIndex;

              return GestureDetector(
                key: _getKeyForIndex(index),
                onTap: widget.isLocked ? null : () => _onLyricTap(index),
                onLongPress: widget.onLongPress,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withValues(alpha: 0.3)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        texts.primary,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: isActive
                                  ? Theme.of(context).colorScheme.primary
                                  : isPast
                                      ? Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant
                                          .withValues(alpha: 0.5)
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                              fontWeight: isActive
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: isActive
                                  ? lyricSettings.fullActiveFontSize
                                  : lyricSettings.fullInactiveFontSize,
                              height: lyricSettings.fullLineHeight,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      if (texts.secondary != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          texts.secondary!,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: isActive
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant
                                            .withValues(
                                              alpha: isPast ? 0.45 : 0.8,
                                            ),
                                    fontSize: lyricSettings
                                            .fullInactiveFontSize *
                                        0.88,
                                    height: lyricSettings.fullLineHeight,
                                  ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(child: Text(S.of(context).loadFailed)),
    );
  }
}
