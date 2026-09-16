import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../models/work.dart';
import '../providers/auth_provider.dart';
import '../providers/subtitle_library_provider.dart';
import '../providers/work_card_display_provider.dart';
import '../screens/work_detail_screen.dart';
import '../utils/age_rating.dart';
import '../utils/snackbar_util.dart';
import '../utils/string_utils.dart';
import 'age_rating_chip.dart';
import 'privacy_blur_cover.dart';
import 'work_bookmark_manager.dart';

class HomeArtworkWorkCard extends ConsumerStatefulWidget {
  const HomeArtworkWorkCard({
    super.key,
    required this.work,
    required this.crossAxisCount,
    required this.isListLayout,
  });

  final Work work;
  final int crossAxisCount;
  final bool isListLayout;

  @override
  ConsumerState<HomeArtworkWorkCard> createState() =>
      _HomeArtworkWorkCardState();
}

class _HomeArtworkWorkCardState extends ConsumerState<HomeArtworkWorkCard> {
  String? _progress;
  int? _rating;
  bool _loadingProgress = false;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _progress = widget.work.progress;
    _rating = widget.work.userRating;
  }

  Future<void> _onLongPress() async {
    if (_loadingProgress || _updating) return;
    setState(() => _loadingProgress = true);
    try {
      final api = ref.read(kikoeruApiServiceProvider);
      final json = await api.getWork(widget.work.id);
      final detailed = Work.fromJson(json);
      if (!mounted) return;
      setState(() {
        _progress = detailed.progress;
        _rating = detailed.userRating;
        _loadingProgress = false;
      });
      await _showEditSheet();
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingProgress = false);
      SnackBarUtil.showError(
        context,
        S.of(context).getStatusFailed(error.toString()),
      );
    }
  }

  Future<void> _showEditSheet() async {
    if (_updating) return;
    setState(() => _updating = true);
    final manager = WorkBookmarkManager(ref: ref, context: context);
    await manager.showMarkDialog(
      workId: widget.work.id,
      currentProgress: _progress,
      currentRating: _rating,
      workTitle: widget.work.title,
      onChanged: (progress, rating) {
        if (!mounted) return;
        setState(() {
          _progress = progress;
          _rating = rating;
        });
      },
    );
    if (mounted) setState(() => _updating = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(
      authProvider.select(
        (state) => (host: state.host ?? '', token: state.token ?? ''),
      ),
    );
    final settings = ref.watch(workCardDisplayProvider);
    final hasLocalSubtitle = ref.watch(
      subtitleLibraryProvider.select((ids) => ids.contains(widget.work.id)),
    );
    final coverUrl = _coverUrl(auth.host, auth.token);
    final initialCover = coverUrl == null
        ? null
        : CachedNetworkImageProvider(coverUrl) as ImageProvider<Object>;

    void openDetail() {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WorkDetailScreen(
            work: widget.work,
            initialCoverImageProvider: initialCover,
          ),
        ),
      );
    }

    if (widget.isListLayout) {
      return _buildListCard(
        context,
        coverUrl: coverUrl,
        settings: settings,
        hasLocalSubtitle: hasLocalSubtitle,
        onTap: openDetail,
      );
    }

    return _buildGridCard(
      context,
      coverUrl: coverUrl,
      settings: settings,
      hasLocalSubtitle: hasLocalSubtitle,
      onTap: openDetail,
    );
  }

  Widget _buildGridCard(
    BuildContext context, {
    required String? coverUrl,
    required WorkCardDisplaySettings settings,
    required bool hasLocalSubtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final compact = widget.crossAxisCount >= 3;
    final titleSize = settings.scaleFontSize(compact ? 12.0 : 14.0);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.surfaceContainerHigh.withValues(
              alpha: isDark ? 0.96 : 0.99,
            ),
            scheme.surfaceContainerLow.withValues(
              alpha: isDark ? 0.96 : 0.99,
            ),
          ],
        ),
        border: Border.all(
          color: scheme.primary.withValues(alpha: isDark ? 0.18 : 0.12),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: isDark ? 0.24 : 0.09),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: scheme.primary.withValues(alpha: isDark ? 0.07 : 0.04),
            blurRadius: 28,
            spreadRadius: -12,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            onLongPress: _onLongPress,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AspectRatio(
                  aspectRatio: compact ? 1.08 : 1.0,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _Artwork(url: coverUrl),
                      const _ArtworkScrim(),
                      Positioned(
                        left: 9,
                        top: 9,
                        child: _GlassPill(
                          icon: Icons.graphic_eq_rounded,
                          label: 'ASMR.one',
                          compact: compact,
                        ),
                      ),
                      if (settings.showAgeRating &&
                          AgeRatingFormatter.hasValue(widget.work.age))
                        Positioned(
                          right: 9,
                          top: 9,
                          child: AgeRatingChip(
                            age: widget.work.age,
                            compact: true,
                          ),
                        ),
                      if (settings.showSubtitleTag &&
                          (widget.work.hasSubtitle == true || hasLocalSubtitle))
                        Positioned(
                          left: 9,
                          bottom: 9,
                          child: _GlassPill(
                            icon: hasLocalSubtitle
                                ? Icons.offline_pin_rounded
                                : Icons.closed_caption_rounded,
                            label: hasLocalSubtitle ? 'Subtitle lokal' : 'Subtitle',
                            compact: true,
                          ),
                        ),
                      if (settings.showDuration &&
                          widget.work.duration != null &&
                          widget.work.duration! > 0)
                        Positioned(
                          right: 9,
                          bottom: 9,
                          child: _GlassPill(
                            icon: Icons.schedule_rounded,
                            label: formatDuration(
                              Duration(seconds: widget.work.duration!),
                            ),
                            compact: true,
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 10 : 13,
                    compact ? 9 : 12,
                    compact ? 10 : 13,
                    compact ? 10 : 13,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.work.displayId,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                          if (_progress != null)
                            Icon(
                              Icons.bookmark_rounded,
                              size: compact ? 14 : 16,
                              color: scheme.primary,
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        widget.work.title,
                        maxLines: compact ? 2 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: scheme.onSurface,
                          fontSize: titleSize,
                          fontWeight: FontWeight.w800,
                          height: 1.18,
                          letterSpacing: -0.15,
                        ),
                      ),
                      if (settings.showCircle &&
                          widget.work.name?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 6),
                        Text(
                          widget.work.name!.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontSize: settings.scaleFontSize(compact ? 10 : 11),
                          ),
                        ),
                      ],
                      if (!compact && _hasBottomMeta(settings)) ...[
                        const SizedBox(height: 10),
                        _BottomMeta(work: widget.work, settings: settings),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListCard(
    BuildContext context, {
    required String? coverUrl,
    required WorkCardDisplaySettings settings,
    required bool hasLocalSubtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: scheme.surfaceContainer.withValues(alpha: isDark ? 0.96 : 0.99),
        border: Border.all(
          color: scheme.primary.withValues(alpha: isDark ? 0.18 : 0.12),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: isDark ? 0.20 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            onLongPress: _onLongPress,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 124,
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _Artwork(url: coverUrl),
                            const _ArtworkScrim(),
                            Positioned(
                              left: 8,
                              bottom: 8,
                              child: _GlassPill(
                                icon: Icons.graphic_eq_rounded,
                                label: 'ASMR.one',
                                compact: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.work.displayId,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (_progress != null)
                                Icon(
                                  Icons.bookmark_rounded,
                                  size: 17,
                                  color: scheme.primary,
                                ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            widget.work.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: scheme.onSurface,
                              fontSize: settings.scaleFontSize(15),
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                              letterSpacing: -0.15,
                            ),
                          ),
                          if (settings.showCircle &&
                              widget.work.name?.trim().isNotEmpty == true) ...[
                            const SizedBox(height: 5),
                            Text(
                              widget.work.name!.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          const SizedBox(height: 9),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (settings.showSubtitleTag &&
                                  (widget.work.hasSubtitle == true ||
                                      hasLocalSubtitle))
                                _MetaChip(
                                  icon: Icons.closed_caption_rounded,
                                  label: hasLocalSubtitle
                                      ? 'Subtitle lokal'
                                      : 'Subtitle',
                                ),
                              if (settings.showDuration &&
                                  widget.work.duration != null &&
                                  widget.work.duration! > 0)
                                _MetaChip(
                                  icon: Icons.schedule_rounded,
                                  label: formatDuration(
                                    Duration(seconds: widget.work.duration!),
                                  ),
                                ),
                              if (settings.showReleaseDate &&
                                  widget.work.release?.isNotEmpty == true)
                                _MetaChip(
                                  icon: Icons.calendar_today_rounded,
                                  label: widget.work.release!,
                                ),
                            ],
                          ),
                          if (_hasBottomMeta(settings)) ...[
                            const SizedBox(height: 9),
                            _BottomMeta(work: widget.work, settings: settings),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _coverUrl(String host, String token) {
    if (host.isNotEmpty) {
      return widget.work.getCoverImageUrl(host, token: token);
    }
    if (widget.work.images?.isNotEmpty == true) {
      return widget.work.images!.first;
    }
    return null;
  }

  bool _hasBottomMeta(WorkCardDisplaySettings settings) {
    return (settings.showPrice && widget.work.price != null) ||
        (settings.showRating &&
            widget.work.rateAverage != null &&
            widget.work.rateCount != null &&
            widget.work.rateCount! > 0) ||
        (settings.showSales && widget.work.dlCount != null);
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final value = url?.trim();
    final child = value == null || value.isEmpty
        ? DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.primaryContainer,
                  scheme.surfaceContainerHighest,
                ],
              ),
            ),
            child: Center(
              child: Icon(
                Icons.graphic_eq_rounded,
                size: 46,
                color: scheme.primary,
              ),
            ),
          )
        : CachedNetworkImage(
            imageUrl: value,
            fit: BoxFit.cover,
            placeholder: (_, __) => ColoredBox(
              color: scheme.surfaceContainerHighest,
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.primary,
                  ),
                ),
              ),
            ),
            errorWidget: (_, __, ___) => ColoredBox(
              color: scheme.surfaceContainerHighest,
              child: Center(
                child: Icon(
                  Icons.graphic_eq_rounded,
                  size: 42,
                  color: scheme.primary,
                ),
              ),
            ),
          );

    return PrivacyBlurCover(child: child);
  }
}

class _ArtworkScrim extends StatelessWidget {
  const _ArtworkScrim();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.06),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.32),
          ],
          stops: const [0, 0.54, 1],
        ),
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({
    required this.icon,
    required this.label,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
          width: 0.7,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 12 : 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontSize: compact ? 9.5 : 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: scheme.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomMeta extends StatelessWidget {
  const _BottomMeta({required this.work, required this.settings});

  final Work work;
  final WorkCardDisplaySettings settings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = <Widget>[];

    if (settings.showRating &&
        work.rateAverage != null &&
        work.rateCount != null &&
        work.rateCount! > 0) {
      items.add(
        _InlineMeta(
          icon: Icons.star_rounded,
          label: work.rateAverage!.toStringAsFixed(1),
        ),
      );
    }
    if (settings.showSales && work.dlCount != null) {
      items.add(
        _InlineMeta(
          icon: Icons.headphones_rounded,
          label: '${work.dlCount}',
        ),
      );
    }

    return Row(
      children: [
        ...items.expand((item) sync* {
          yield item;
          yield const SizedBox(width: 10);
        }),
        const Spacer(),
        if (settings.showPrice && work.price != null)
          Text(
            S.of(context).priceInYen(work.price!),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
      ],
    );
  }
}

class _InlineMeta extends StatelessWidget {
  const _InlineMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: scheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
