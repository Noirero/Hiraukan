import 'package:flutter/material.dart';
import 'package:real_liquid_glass/real_liquid_glass.dart';

import 'liquid_glass_layout.dart';

class MainBottomNavigationBar extends StatelessWidget {
  const MainBottomNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.miniPlayer = const SizedBox.shrink(),
    this.liquidGlass = false,
    this.fallbackGlassTransparency = 0.4,
    this.showUpdateBadge = false,
    this.onLayoutExtentChanged,
  });

  static const double navigationBarHeight = 70;

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;
  final Widget miniPlayer;
  final bool liquidGlass;
  final double fallbackGlassTransparency;
  final bool showUpdateBadge;
  final ValueChanged<double>? onLayoutExtentChanged;

  @override
  Widget build(BuildContext context) {
    if (liquidGlass) {
      return _LiquidGlassBottomNavigation(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: destinations,
        miniPlayer: miniPlayer,
        fallbackGlassTransparency: fallbackGlassTransparency,
        showUpdateBadge: showUpdateBadge,
        onLayoutExtentChanged: onLayoutExtentChanged,
      );
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        miniPlayer,
        SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(14, 6, 14, 10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: scheme.primary.withValues(
                  alpha: isDark ? 0.22 : 0.18,
                ),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withValues(
                    alpha: isDark ? 0.34 : 0.12,
                  ),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: scheme.primary.withValues(
                    alpha: isDark ? 0.14 : 0.09,
                  ),
                  blurRadius: 28,
                  spreadRadius: -8,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Material(
                color: scheme.surfaceContainer.withValues(
                  alpha: isDark ? 0.97 : 0.985,
                ),
                child: SizedBox(
                  height: navigationBarHeight,
                  child: Row(
                    children: [
                      for (var index = 0;
                          index < destinations.length;
                          index++)
                        Expanded(
                          child: _PremiumNavigationItem(
                            destination: destinations[index],
                            selected: selectedIndex == index,
                            onTap: () => onDestinationSelected(index),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PremiumNavigationItem extends StatelessWidget {
  const _PremiumNavigationItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavigationDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 7),
      child: Semantics(
        selected: selected,
        button: true,
        label: destination.label,
        child: InkWell(
          borderRadius: BorderRadius.circular(21),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(21),
              gradient: selected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        scheme.primary.withValues(
                          alpha: isDark ? 0.24 : 0.18,
                        ),
                        scheme.secondaryContainer.withValues(
                          alpha: isDark ? 0.40 : 0.56,
                        ),
                      ],
                    )
                  : null,
              border: selected
                  ? Border.all(
                      color: scheme.primary.withValues(
                        alpha: isDark ? 0.34 : 0.24,
                      ),
                      width: 0.8,
                    )
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: selected ? 1.06 : 1,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: IconTheme(
                    data: IconThemeData(
                      color: selected
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                      size: selected ? 23 : 21,
                    ),
                    child: selected
                        ? (destination.selectedIcon ?? destination.icon)
                        : destination.icon,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: selected
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                    fontSize: 10.5,
                    height: 1.05,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: selected ? 0.1 : 0,
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

class _LiquidGlassBottomNavigation extends StatelessWidget {
  const _LiquidGlassBottomNavigation({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.miniPlayer,
    required this.fallbackGlassTransparency,
    required this.showUpdateBadge,
    required this.onLayoutExtentChanged,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;
  final Widget miniPlayer;
  final double fallbackGlassTransparency;
  final bool showUpdateBadge;
  final ValueChanged<double>? onLayoutExtentChanged;

  static const _items = [
    (
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      sfSymbol: 'house',
      selectedSfSymbol: 'house.fill',
    ),
    (
      icon: Icons.search_outlined,
      selectedIcon: Icons.search,
      sfSymbol: 'magnifyingglass',
      selectedSfSymbol: 'magnifyingglass',
    ),
    (
      icon: Icons.favorite_border,
      selectedIcon: Icons.favorite,
      sfSymbol: 'heart',
      selectedSfSymbol: 'heart.fill',
    ),
    (
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      sfSymbol: 'gearshape',
      selectedSfSymbol: 'gearshape.fill',
    ),
  ];

  List<LiquidGlassBarItem> _itemsForDestinations() {
    return [
      for (var index = 0; index < destinations.length; index++)
        LiquidGlassBarItem(
          icon: index < _items.length
              ? _items[index].icon
              : Icons.circle_outlined,
          selectedIcon: index < _items.length
              ? _items[index].selectedIcon
              : Icons.circle,
          sfSymbol: index < _items.length ? _items[index].sfSymbol : 'circle',
          selectedSfSymbol: index < _items.length
              ? _items[index].selectedSfSymbol
              : 'circle.fill',
          label: destinations[index].label,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final navigationBarHeight = LiquidGlassLayout.navigationBarHeight(context);
    return LiquidGlassDockExtentReporter(
      onChanged: onLayoutExtentChanged ?? (_) {},
      child: Padding(
        padding: EdgeInsets.only(
          bottom: LiquidGlassLayout.dockBottomInset(context),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              alignment: Alignment.bottomCenter,
              child: miniPlayer,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LiquidGlassLayout.horizontalPadding,
                LiquidGlassLayout.verticalPadding,
                LiquidGlassLayout.horizontalPadding,
                LiquidGlassLayout.navigationBarBottomPadding,
              ),
              child: SizedBox(
                height: navigationBarHeight,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final expansion = LiquidGlassLayout.nativeTabBarExpansion(
                      context,
                    );
                    final barWidth = constraints.maxWidth + expansion * 2;
                    final bar = ClipRRect(
                      borderRadius: BorderRadius.circular(
                        navigationBarHeight / 2,
                      ),
                      child: SizedBox(
                        width: barWidth,
                        child: LiquidGlassBottomBar(
                          items: _itemsForDestinations(),
                          currentIndex: selectedIndex,
                          onTap: onDestinationSelected,
                          height: navigationBarHeight,
                          showLabels: true,
                          tint: Theme.of(context).colorScheme.primary,
                          fallbackIntensity: fallbackGlassTransparency,
                        ),
                      ),
                    );

                    final expandedBar = expansion == 0
                        ? bar
                        : OverflowBox(
                            minWidth: barWidth,
                            maxWidth: barWidth,
                            minHeight: navigationBarHeight,
                            maxHeight: navigationBarHeight,
                            alignment: Alignment.center,
                            child: bar,
                          );

                    if (!showUpdateBadge || destinations.isEmpty) {
                      return expandedBar;
                    }

                    final itemWidth = barWidth / destinations.length;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        expandedBar,
                        Positioned(
                          top: 10,
                          left: itemWidth * (destinations.length - 0.5) - 4,
                          child: IgnorePointer(
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.error,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.surface,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
