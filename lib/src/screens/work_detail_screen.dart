import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/snackbar_util.dart';
import '../../l10n/app_localizations.dart';

import '../models/work.dart';
import '../providers/auth_provider.dart';
import '../widgets/scrollable_appbar.dart';
import '../services/work_track_file_builder.dart';
import '../services/offline_package_service.dart';
import '../utils/system_ui_style.dart';
import '../widgets/file_explorer_widget.dart';
import '../widgets/file_selection_dialog.dart';
import '../widgets/global_audio_player_wrapper.dart';
import '../widgets/responsive_dialog.dart';
import '../widgets/work_bookmark_manager.dart';
import '../widgets/rating_detail_popup.dart';
import '../services/translation_service.dart';
import '../widgets/download_fab.dart';
import '../providers/work_detail_display_provider.dart';
import '../widgets/work_detail/tag_vote_dialog.dart';
import '../widgets/work_detail/add_tag_dialog.dart';
import '../widgets/work_detail/recommendation_section.dart';
import '../widgets/work_detail/work_title_header.dart';
import '../widgets/work_detail/work_metadata_sections.dart';
import '../widgets/work_detail/work_stats_section.dart';
import '../widgets/work_detail/work_extra_sections.dart';
import '../widgets/work_detail/work_cover_frame.dart';
import '../widgets/work_detail/work_detail_responsive_layout.dart';
import '../widgets/work_detail/work_detail_error_banner.dart';
import '../widgets/work_detail/work_progress_action_button.dart';

import '../widgets/image_gallery_screen.dart';

class WorkDetailScreen extends ConsumerStatefulWidget {
  final Work work;
  final String? heroTag;
  final ImageProvider<Object>? initialCoverImageProvider;

  const WorkDetailScreen({
    super.key,
    required this.work,
    this.heroTag,
    this.initialCoverImageProvider,
  });

  @override
  ConsumerState<WorkDetailScreen> createState() => _WorkDetailScreenState();
}

class _WorkDetailScreenState extends ConsumerState<WorkDetailScreen> {
  Work? _detailedWork;
  String? _errorMessage;
  bool _showHDImage = false;
  ImageProvider? _hdImageProvider;
  String? _currentProgress;
  int? _currentRating;
  bool _isUpdatingProgress = false;
  bool _isOpeningFileSelection = false;
  bool _isOpeningProgressDialog = false;
  bool _isMakingOffline = false;
  final FileExplorerController _fileExplorerController =
      FileExplorerController();

  String? _translatedTitle;
  bool _showTranslation = false;
  bool _isTranslating = false;

  Future<void> _restoreMiniPlayerAfterModalExit(VoidCallback clearFlag) async {
    await Future<void>.delayed(kThemeAnimationDuration);
    if (mounted) {
      setState(clearFlag);
    } else {
      clearFlag();
    }
  }

  @override
  void initState() {
    super.initState();
    _currentProgress = widget.work.progress;
    _currentRating = widget.work.userRating;
    _loadWorkDetail();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        _preloadHDImage();
      }
    });
  }

  Future<void> _preloadHDImage() async {
    final authState = ref.read(authProvider);
    final host = authState.host ?? '';
    final token = authState.token ?? '';

    if (host.isEmpty) return;

    final imageUrl = widget.work.getCoverImageUrl(host, token: token);
    final imageProvider = NetworkImage(imageUrl);

    try {
      await precacheImage(imageProvider, context);
      if (mounted) {
        setState(() {
          _hdImageProvider = imageProvider;
          _showHDImage = true;
        });
      }
    } catch (e) {
      debugPrint('HD image preload failed: $e');
    }
  }

  Future<void> _translateTitle() async {
    if (_isTranslating) return;

    final work = _detailedWork ?? widget.work;

    if (_translatedTitle != null) {
      setState(() {
        _showTranslation = !_showTranslation;
      });
      return;
    }

    setState(() {
      _isTranslating = true;
    });

    try {
      final translationService = TranslationService();
      final translated =
          await translationService.translate(work.title, sourceLang: 'ja');

      if (mounted) {
        setState(() {
          _translatedTitle = translated;
          _showTranslation = true;
          _isTranslating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTranslating = false;
        });

        SnackBarUtil.showError(
          context,
          S.of(context).translationFailed(e.toString()),
          duration: const Duration(seconds: 2),
        );
      }
    }
  }

  Future<void> _copyToClipboard(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      SnackBarUtil.showSuccess(
        context,
        S.of(context).copiedToClipboard(label, text),
        duration: const Duration(seconds: 2),
      );
    }
  }

  void _showTagInfo(Tag tag) {
    showDialog(
      context: context,
      builder: (context) => TagVoteDialog(
        tag: tag,
        workId: widget.work.id,
        onVoteChanged: (updatedTag) {
          if (mounted) {
            setState(() {
              if (_detailedWork != null && _detailedWork!.tags != null) {
                final tagIndex = _detailedWork!.tags!
                    .indexWhere((t) => t.id == updatedTag.id);
                if (tagIndex != -1) {
                  final updatedTags = List<Tag>.from(_detailedWork!.tags!);
                  updatedTags[tagIndex] = updatedTag;
                  _detailedWork = _detailedWork!.copyWith(tags: updatedTags);
                }
              }
            });
          }
        },
        onCopyTag: () => _copyToClipboard(tag.name, S.of(context).tagLabel),
      ),
    );
  }

  void _showAddTagDialog() {
    showDialog(
      context: context,
      builder: (context) => AddTagDialog(
        workId: widget.work.id,
        existingTags: _detailedWork?.tags ?? widget.work.tags ?? [],
        onTagsAdded: () {
          _loadWorkDetail();
        },
      ),
    );
  }

  Future<void> _openSourceUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        final fallbackLaunched = await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
        );

        if (!fallbackLaunched && mounted) {
          SnackBarUtil.showWarning(
            context,
            S.of(context).cannotOpenLink,
            duration: const Duration(seconds: 2),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtil.showError(
          context,
          S.of(context).openLinkFailed(e.toString()),
          duration: const Duration(seconds: 2),
        );
      }
    }
  }

  Future<void> _showFileSelectionDialog() async {
    if (_isOpeningFileSelection) return;
    setState(() => _isOpeningFileSelection = true);

    final preparedWorkFuture = _prepareWorkForFileSelection();

    try {
      await showResponsiveBottomSheet<void>(
        context: context,
        maxHeight: MediaQuery.of(context).size.height * 0.9,
        builder: (dialogContext) {
          return FutureBuilder<Work>(
            future: preparedWorkFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(S.of(context).loadingFileList),
                      ],
                    ),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BottomSheetHeader(
                      title: S.of(context).loadFailed,
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(S
                          .of(context)
                          .loadFileListFailed(snapshot.error.toString())),
                    ),
                  ],
                );
              }

              final work = snapshot.data!;
              return FileSelectionDialog(work: work);
            },
          );
        },
      );
    } finally {
      await _restoreMiniPlayerAfterModalExit(
        () => _isOpeningFileSelection = false,
      );
    }
  }

  Future<Work> _prepareWorkForFileSelection() async {
    final apiService = ref.read(kikoeruApiServiceProvider);
    final files = await apiService.getWorkTracks(widget.work.id);
    final authState = ref.read(authProvider);
    final trackFileBuilder = WorkTrackFileBuilder(
      host: authState.host ?? '',
      token: authState.token ?? '',
    );
    final baseWork = _detailedWork ?? widget.work;
    return trackFileBuilder.withTracks(work: baseWork, files: files);
  }

  Future<void> _makeAvailableOffline() async {
    if (_isMakingOffline) return;
    setState(() => _isMakingOffline = true);
    try {
      final work = await _prepareWorkForFileSelection();
      final authState = ref.read(authProvider);
      final host = authState.host ?? '';
      final token = authState.token ?? '';
      final coverUrl = work.getCoverImageUrl(host, token: token);
      final result = await OfflinePackageService.instance.makeAvailableOffline(
        work: work,
        host: host,
        token: token,
        coverUrl: coverUrl,
      );
      if (!mounted) return;

      final isIndonesian = Localizations.localeOf(context).languageCode == 'id';
      if (result.queued > 0) {
        SnackBarUtil.showSuccess(
          context,
          isIndonesian
              ? '${result.queued} file ditambahkan ke antrean offline.'
              : '${result.queued} files added to the offline queue.',
          duration: const Duration(seconds: 3),
        );
      } else {
        SnackBarUtil.showInfo(
          context,
          isIndonesian
              ? 'Karya ini sudah tersedia atau sedang disiapkan untuk offline.'
              : 'This work is already available or being prepared for offline use.',
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final isIndonesian = Localizations.localeOf(context).languageCode == 'id';
      SnackBarUtil.showError(
        context,
        isIndonesian
            ? 'Gagal menyiapkan offline: $e'
            : 'Could not prepare offline files: $e',
        duration: const Duration(seconds: 3),
      );
    } finally {
      if (mounted) setState(() => _isMakingOffline = false);
    }
  }

  Future<void> _loadWorkDetail() async {
    try {
      setState(() {
        _errorMessage = null;
      });

      final apiService = ref.read(kikoeruApiServiceProvider);
      final response = await apiService.getWork(widget.work.id);
      final detailedWork = Work.fromJson(response);

      if (mounted) {
        setState(() {
          _detailedWork = detailedWork;
          _currentProgress = detailedWork.progress;
          _currentRating = detailedWork.userRating;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = S.of(context).loadFailedWithError(e.toString());
        });
      }
    }
  }

  Future<void> _refreshWorkDetail() async {
    try {
      setState(() {
        _errorMessage = null;
      });

      final apiService = ref.read(kikoeruApiServiceProvider);

      final refreshResults = await Future.wait<dynamic>([
        apiService.getWork(widget.work.id, forceRefresh: true),
        _fileExplorerController.refresh(forceRefresh: true),
      ]);
      final response = refreshResults.first as Map<String, dynamic>;
      final detailedWork = Work.fromJson(response);

      if (mounted) {
        setState(() {
          _detailedWork = detailedWork;
          _currentProgress = detailedWork.progress;
          _currentRating = detailedWork.userRating;
        });

        SnackBarUtil.showSuccess(
          context,
          S.of(context).refreshComplete,
          duration: const Duration(seconds: 1),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = S.of(context).refreshFailed(e.toString());
        });

        SnackBarUtil.showError(
          context,
          S.of(context).refreshFailed(e.toString()),
          duration: const Duration(seconds: 2),
        );
      }
    }
  }

  Future<void> _showProgressDialog() async {
    if (_isOpeningProgressDialog) return;
    setState(() => _isOpeningProgressDialog = true);

    final manager = WorkBookmarkManager(ref: ref, context: context);

    try {
      await manager.showMarkDialog(
        workId: widget.work.id,
        currentProgress: _currentProgress,
        currentRating: _currentRating,
        workTitle: widget.work.title,
        onChanged: (newProgress, newRating) {
          if (mounted) {
            setState(() {
              _currentProgress = newProgress;
              _currentRating = newRating;
              _isUpdatingProgress = false;
            });
          }
        },
      );
    } finally {
      await _restoreMiniPlayerAfterModalExit(
        () => _isOpeningProgressDialog = false,
      );
    }
  }

  Future<void> _showRatingDetailDialog(Work work) async {
    if (work.rateCountDetail == null || work.rateCountDetail!.isEmpty) return;
    if (work.rateAverage == null || work.rateCount == null) return;

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: RatingDetailPopup(
          ratingDetails: work.rateCountDetail!,
          averageRating: work.rateAverage!,
          totalCount: work.rateCount!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final systemOverlayStyle = transparentSystemBarsForBrightness(brightness);
    final isIndonesian = Localizations.localeOf(context).languageCode == 'id';

    return GlobalAudioPlayerWrapper(
      suppressLiquidGlassMiniPlayer:
          _isOpeningFileSelection || _isOpeningProgressDialog,
      child: Scaffold(
        floatingActionButton: const DownloadFab(),
        appBar: ScrollableAppBar(
          systemOverlayStyle: systemOverlayStyle,
          title: GestureDetector(
            onLongPress: () => _copyToClipboard(
              widget.work.displayId,
              S.of(context).workIdLabel,
            ),
            child: Text(
              widget.work.displayId,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: _isMakingOffline
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_for_offline_outlined),
              onPressed: _isMakingOffline ? null : _makeAvailableOffline,
              tooltip: isIndonesian
                  ? 'Jadikan tersedia offline'
                  : 'Make available offline',
            ),
            IconButton(
              icon: const Icon(Icons.download_outlined),
              onPressed: _showFileSelectionDialog,
              tooltip: isIndonesian
                  ? 'Pilih file untuk diunduh'
                  : 'Choose files to download',
            ),
            WorkProgressActionButton(
              progress: _currentProgress,
              isLoading: _isUpdatingProgress,
              onPressed: _showProgressDialog,
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final authState = ref.watch(authProvider);
    final host = authState.host ?? '';
    final token = authState.token ?? '';

    final work = _detailedWork ?? widget.work;

    final effectiveHeroTag = widget.heroTag ?? 'work_cover_${widget.work.id}';
    final coverUrl = work.getCoverImageUrl(host, token: token);
    final displaySettings = ref.watch(workDetailDisplayProvider);
    final showSubtitleBadge =
        displaySettings.showSubtitleTag && work.hasSubtitle == true;

    final infoWidget = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Consumer(
            builder: (context, ref, _) {
              final displaySettings = ref.watch(workDetailDisplayProvider);
              return WorkTitleHeader(
                title: work.title,
                translatedTitle: _translatedTitle,
                showTranslation: _showTranslation,
                showTranslateButton: displaySettings.showTranslateButton,
                isTranslating: _isTranslating,
                showExternalLink:
                    displaySettings.showExternalLinks && work.sourceUrl != null,
                onTranslate: _translateTitle,
                onOpenExternalLink: work.sourceUrl == null
                    ? null
                    : () => _openSourceUrl(work.sourceUrl!),
                onCopy: (title) => _copyToClipboard(
                  title,
                  S.of(context).titleLabel,
                ),
              );
            },
          ),
          const SizedBox(height: 8),

          WorkDetailErrorBanner(
            message: _errorMessage,
            onRetry: _loadWorkDetail,
          ),

          Consumer(
            builder: (context, ref, _) {
              final displaySettings = ref.watch(workDetailDisplayProvider);
              return WorkStatsSection(
                work: work,
                currentRating: _currentRating,
                showRating: displaySettings.showRating,
                showPrice: displaySettings.showPrice,
                showDuration: displaySettings.showDuration,
                showSales: displaySettings.showSales,
                onShowRatingDetails: () => _showRatingDetailDialog(work),
                onShowProgress: _showProgressDialog,
              );
            },
          ),

          const SizedBox(height: 16),

          WorkCreatorChipsSection(
            work: work,
            onCopy: _copyToClipboard,
          ),

          WorkTagChipsSection(
            tags: work.tags,
            onTagLongPress: _showTagInfo,
            onTagSecondaryTap: _showTagInfo,
            onAddTag: _showAddTagDialog,
          ),

          Consumer(
            builder: (context, ref, _) {
              final displaySettings = ref.watch(workDetailDisplayProvider);
              return WorkReleaseDateSection(
                release: work.release,
                visible: displaySettings.showReleaseDate,
              );
            },
          ),

          OtherLanguageEditionsSection(
            editions: work.otherLanguageEditions,
            onEditionSelected: (edition) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => WorkDetailScreen(
                    work: Work(
                      id: edition.id,
                      title: edition.title,
                    ),
                  ),
                ),
              );
            },
          ),

          FileExplorerWidget(
            work: work,
            controller: _fileExplorerController,
          ),

          RecommendationSection(work: work),
        ],
      ),
    );

    return WorkDetailResponsiveLayout(
      onRefresh: _refreshWorkDetail,
      coverBuilder: (context, isLandscape) {
        return WorkCoverFrame(
          heroTag: effectiveHeroTag,
          isLandscape: isLandscape,
          showSubtitleBadge: showSubtitleBadge,
          showAgeRating: displaySettings.showAgeRating,
          age: work.age,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ImageGalleryScreen(
                  images: [
                    {
                      'url': coverUrl,
                      'title': work.title,
                      'hash': '',
                    },
                  ],
                  initialIndex: 0,
                ),
              ),
            );
          },
          layers: [
            CachedNetworkImage(
              imageUrl: coverUrl,
              cacheKey: 'work_cover_${widget.work.id}',
              fit: BoxFit.contain,
              placeholder: (context, url) => _buildCoverPlaceholder(),
              errorWidget: (context, url, error) => _buildCoverPlaceholder(),
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
              placeholderFadeInDuration: Duration.zero,
            ),
            if (_showHDImage && _hdImageProvider != null)
              Image(
                image: _hdImageProvider!,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox.shrink();
                },
              ),
          ],
        );
      },
      info: infoWidget,
    );
  }

  Widget _buildCoverPlaceholder() {
    final initialCover = widget.initialCoverImageProvider;
    if (initialCover != null) {
      return Image(
        image: initialCover,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) =>
            _buildMissingCoverPlaceholder(),
      );
    }
    return _buildMissingCoverPlaceholder();
  }

  Widget _buildMissingCoverPlaceholder() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 300,
      color: colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.image_not_supported,
        size: 64,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
}
