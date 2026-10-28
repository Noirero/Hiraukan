import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/history_provider.dart';
import 'history_work_card.dart';

/// A compact home shelf backed by the existing persisted playback history.
///
/// Resume behavior is delegated to [HistoryWorkCard], so this surface reuses
/// the same queue reconstruction, offline fallback, unified-source resolution,
/// and seek semantics as the Library history screen.
class ContinueListeningSection extends ConsumerWidget {
  const ContinueListeningSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(historyProvider);
    final records = state.records
        .where((record) => record.lastTrack != null)
        .take(6)
        .toList(growable: false);

    if (records.isEmpty) return const SizedBox.shrink();

    final copy = _ContinueCopy.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    copy.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    copy.subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            Icon(Icons.history_rounded, color: scheme.primary),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 244,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: records.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) => SizedBox(
              width: 172,
              child: HistoryWorkCard(record: records[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _ContinueCopy {
  const _ContinueCopy({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  static _ContinueCopy of(BuildContext context) {
    if (Localizations.localeOf(context).languageCode == 'id') {
      return const _ContinueCopy(
        title: 'Lanjut Dengarkan',
        subtitle: 'Kembali tepat ke karya dan posisi terakhir.',
      );
    }
    return const _ContinueCopy(
      title: 'Continue Listening',
      subtitle: 'Return to your recent works and saved position.',
    );
  }
}
