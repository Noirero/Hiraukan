import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/audio_track.dart';
import '../../utils/local_file_url.dart';
import '../privacy_blur_cover.dart';

/// Immersive artwork surface used by the Hiraukan player.
class PlayerCoverWidget extends StatelessWidget {
  final AudioTrack track;
  final String? workCoverUrl;
  final bool isLandscape;
  final VoidCallback? onTap;

  const PlayerCoverWidget({
    super.key,
    required this.track,
    this.workCoverUrl,
    this.isLandscape = false,
    this.onTap,
  });

  bool _isLocalFile(String? url) => LocalFileUrl.isLocalFileUrl(url);

  String _getLocalPath(String fileUrl) {
    return LocalFileUrl.pathFromUrl(fileUrl) ?? fileUrl;
  }

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    const radius = 24.0;

    // Unified sources already attach their provider artwork to the AudioTrack.
    // Prefer it over the legacy ASMR.one cover fallback passed by the player;
    // otherwise HentaiASMR tracks can be shadowed by a non-existent
    // /api/cover/<id> URL and render the placeholder despite having artwork.
    final trackArtwork = track.artworkUrl?.trim();
    final fallbackArtwork = workCoverUrl?.trim();
    final artworkUrl = trackArtwork?.isNotEmpty == true
        ? trackArtwork
        : fallbackArtwork?.isNotEmpty == true
            ? fallbackArtwork
            : null;

    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: Hero(
          tag: 'audio_player_artwork_${track.id}',
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isLandscape ? mediaSize.width * 0.35 : mediaSize.width - 48,
              maxHeight:
                  isLandscape ? mediaSize.height * 0.6 : mediaSize.height * 0.4,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                color: scheme.surfaceContainerHighest,
                border: Border.all(
                  color: scheme.primary.withValues(alpha: isDark ? 0.18 : 0.12),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: isDark ? 0.40 : 0.15),
                    blurRadius: 34,
                    spreadRadius: -6,
                    offset: const Offset(0, 18),
                  ),
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: isDark ? 0.16 : 0.09),
                    blurRadius: 44,
                    spreadRadius: -12,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: artworkUrl != null
                    ? PrivacyBlurCover(
                        borderRadius: BorderRadius.circular(radius),
                        child: _buildArtwork(context, artworkUrl),
                      )
                    : _buildPlaceholder(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArtwork(BuildContext context, String artworkUrl) {
    if (_isLocalFile(artworkUrl)) {
      return Image.file(
        File(_getLocalPath(artworkUrl)),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(context),
      );
    }

    return CachedNetworkImage(
      imageUrl: artworkUrl,
      cacheKey: track.workId != null ? 'work_cover_${track.workId}' : null,
      fit: BoxFit.cover,
      errorWidget: (context, url, error) => _buildPlaceholder(context),
      placeholder: (context, url) => _buildPlaceholder(context),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Icon(
            Icons.graphic_eq_rounded,
            size: isLandscape ? 80 : 112,
            color: scheme.primary.withValues(alpha: 0.72),
          ),
        ),
      ),
    );
  }
}
