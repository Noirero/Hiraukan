import 'package:flutter/material.dart';

import 'floating_feed_toolbar.dart';

/// Premium Home-only toolbar that keeps the conventional feed controls while
/// visually tying them to Hiraukan's lavender/night discovery surface.
class HomeFeedToolbar extends StatelessWidget {
  const HomeFeedToolbar({
    super.key,
    required this.modeActions,
    required this.toolActions,
  }) : assert(modeActions.length > 0);

  final List<FloatingFeedModeAction> modeActions;
  final List<FloatingFeedToolAction> toolActions;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 8.0;
          final toolWidth = toolActions.isEmpty
              ? 0.0
              : 8 + (toolActions.length * 40.0);
          final availableModeWidth =
              (constraints.maxWidth - toolWidth - (toolActions.isEmpty ? 0 : gap))
                  .clamp(0.0, constraints.maxWidth)
                  .toDouble();

          final modeRow = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final action in modeActions)
                _HomeModeButton(action: action),
            ],
          );

          return Row(
            children: [
              Flexible(
                fit: FlexFit.loose,
                child: _HomeToolbarSurface(
                  emphasized: true,
                  child: SizedBox(
                    width: availableModeWidth,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: modeRow,
                    ),
                  ),
                ),
              ),
              if (toolActions.isNotEmpty) ...[
                const SizedBox(width: gap),
                _HomeToolbarSurface(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final action in toolActions)
                        _HomeToolButton(action: action),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _HomeToolbarSurface extends StatelessWidget {
  const _HomeToolbarSurface({
    required this.child,
    this.emphasized = false,
  });

  final Widget child;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: emphasized
              ? [
                  scheme.surfaceContainerHigh.withValues(
                    alpha: isDark ? 0.94 : 0.98,
                  ),
                  scheme.primaryContainer.withValues(
                    alpha: isDark ? 0.34 : 0.46,
                  ),
                ]
              : [
                  scheme.surfaceContainerHigh.withValues(
                    alpha: isDark ? 0.94 : 0.98,
                  ),
                  scheme.surfaceContainer.withValues(
                    alpha: isDark ? 0.92 : 0.96,
                  ),
                ],
        ),
        border: Border.all(
          color: emphasized
              ? scheme.primary.withValues(alpha: isDark ? 0.25 : 0.18)
              : scheme.outlineVariant.withValues(alpha: isDark ? 0.32 : 0.46),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: isDark ? 0.23 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
          if (emphasized)
            BoxShadow(
              color: scheme.primary.withValues(alpha: isDark ? 0.10 : 0.06),
              blurRadius: 24,
              spreadRadius: -9,
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: child,
      ),
    );
  }
}

class _HomeModeButton extends StatelessWidget {
  const _HomeModeButton({required this.action});

  final FloatingFeedModeAction action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Semantics(
      selected: action.isSelected,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: action.onPressed,
          borderRadius: BorderRadius.circular(19),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(19),
              gradient: action.isSelected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        scheme.primaryContainer.withValues(
                          alpha: isDark ? 0.98 : 0.92,
                        ),
                        scheme.primary.withValues(
                          alpha: isDark ? 0.19 : 0.11,
                        ),
                      ],
                    )
                  : null,
              border: action.isSelected
                  ? Border.all(
                      color: scheme.primary.withValues(
                        alpha: isDark ? 0.36 : 0.25,
                      ),
                      width: 0.8,
                    )
                  : null,
              boxShadow: action.isSelected
                  ? [
                      BoxShadow(
                        color: scheme.primary.withValues(
                          alpha: isDark ? 0.12 : 0.07,
                        ),
                        blurRadius: 14,
                        spreadRadius: -5,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: action.isSelected ? 1.06 : 1,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    action.icon,
                    size: 18,
                    color: action.isSelected
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  action.label,
                  maxLines: 1,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: action.isSelected
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                    fontWeight:
                        action.isSelected ? FontWeight.w800 : FontWeight.w600,
                    letterSpacing: action.isSelected ? -0.1 : 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeToolButton extends StatelessWidget {
  const _HomeToolButton({required this.action});

  final FloatingFeedToolAction action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Tooltip(
      message: action.tooltip,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: action.isSelected
              ? scheme.primary.withValues(alpha: isDark ? 0.18 : 0.11)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(19),
          border: action.isSelected
              ? Border.all(
                  color: scheme.primary.withValues(alpha: 0.24),
                  width: 0.7,
                )
              : null,
        ),
        child: IconButton(
          onPressed: action.onPressed,
          icon: Icon(action.icon),
          iconSize: 19,
          padding: EdgeInsets.zero,
          color: action.isSelected ? scheme.primary : scheme.onSurfaceVariant,
          disabledColor: scheme.onSurface.withValues(alpha: 0.28),
          tooltip: null,
        ),
      ),
    );
  }
}
