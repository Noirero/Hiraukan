import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/search_result_provider.dart';
import '../sources/unified_source_models.dart';

class UnifiedSourceFilterBar extends ConsumerWidget {
  const UnifiedSourceFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(searchResultProvider);
    final notifier = ref.read(searchResultProvider.notifier);
    final allSelected = state.enabledSources.length == UnifiedSourceKind.values.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All Sources'),
                  selected: allSelected,
                  onSelected: (_) => notifier.enableAllSources(),
                ),
                const SizedBox(width: 6),
                ...UnifiedSourceKind.values.map((source) {
                  final enabled = state.enabledSources.contains(source);
                  final health = state.sourceHealth[source] ?? UnifiedSourceHealth.unknown;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      avatar: Icon(
                        _healthIcon(health),
                        size: 16,
                        color: _healthColor(context, health),
                      ),
                      label: Text(source.label),
                      selected: enabled,
                      onSelected: (value) => notifier.setSourceEnabled(source, value),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Same work is merged across sources. If one source cannot play it, KikoFlu automatically tries another available source.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  static IconData _healthIcon(UnifiedSourceHealth health) => switch (health) {
        UnifiedSourceHealth.healthy => Icons.check_circle,
        UnifiedSourceHealth.degraded => Icons.warning_amber_rounded,
        UnifiedSourceHealth.broken => Icons.cancel,
        UnifiedSourceHealth.unknown => Icons.help_outline,
      };

  static Color _healthColor(BuildContext context, UnifiedSourceHealth health) =>
      switch (health) {
        UnifiedSourceHealth.healthy => Colors.green,
        UnifiedSourceHealth.degraded => Colors.orange,
        UnifiedSourceHealth.broken => Theme.of(context).colorScheme.error,
        UnifiedSourceHealth.unknown => Theme.of(context).colorScheme.outline,
      };
}
