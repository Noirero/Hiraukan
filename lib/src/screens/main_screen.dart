import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:real_liquid_glass/real_liquid_glass.dart';

import '../../l10n/app_localizations.dart';
import '../providers/audio_provider.dart';
import '../providers/update_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/main_bottom_navigation_bar.dart';
import '../widgets/mini_player.dart';
import '../widgets/liquid_glass_layout.dart';
import 'works_screen.dart';
import 'search_screen.dart';
import 'library_screen.dart';
import 'settings_screen.dart';
import '../providers/settings_provider.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _currentIndex = 0;
  static const int _settingsTabIndex = 3;

  final PageStorageBucket _bucket = PageStorageBucket();
  final ValueNotifier<double> _liquidDockExtent = ValueNotifier(0);
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = const [
      WorksScreen(key: PageStorageKey('works_screen')),
      SearchScreen(key: PageStorageKey('search_screen')),
      LibraryScreen(key: PageStorageKey('library_screen')),
      SettingsScreen(key: PageStorageKey('settings_screen')),
    ];
  }

  @override
  void dispose() {
    _liquidDockExtent.dispose();
    super.dispose();
  }

  List<NavigationDestination> _buildDestinations(
    BuildContext context,
    bool showUpdateBadge,
  ) {
    final s = S.of(context);
    return [
      NavigationDestination(
        icon: const Icon(Icons.home_outlined),
        selectedIcon: const Icon(Icons.home),
        label: s.navHome,
      ),
      NavigationDestination(
        icon: const Icon(Icons.search_outlined),
        selectedIcon: const Icon(Icons.search),
        label: s.navSearch,
      ),
      NavigationDestination(
        icon: const Icon(Icons.library_music_outlined),
        selectedIcon: const Icon(Icons.library_music_rounded),
        label: _libraryLabel(context),
      ),
      NavigationDestination(
        icon: Badge(
          isLabelVisible: showUpdateBadge,
          child: const Icon(Icons.settings_outlined),
        ),
        selectedIcon: Badge(
          isLabelVisible: showUpdateBadge,
          child: const Icon(Icons.settings),
        ),
        label: s.navSettings,
      ),
    ];
  }

  String _libraryLabel(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return switch (locale.languageCode) {
      'id' => 'Koleksi',
      'ja' => 'ライブラリ',
      'ru' => 'Медиатека',
      'zh' => locale.scriptCode == 'Hant' ? '資料庫' : '资料库',
      _ => 'Library',
    };
  }

  void _handleDestinationSelected(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);

    if (index == _settingsTabIndex) {
      ref.read(settingsCacheRefreshTriggerProvider.notifier).state++;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final showUpdateBadge = ref.watch(showUpdateRedDotProvider);
    final useLiquidGlass = ref.watch(liquidGlassNavigationProvider);
    final destinations = _buildDestinations(context, showUpdateBadge);

    if (isLandscape) {
      final mediaSize = MediaQuery.sizeOf(context);
      final mediaPadding = MediaQuery.paddingOf(context);
      final landscapeScaffold = Scaffold(
        body: Stack(
          children: [
            Row(
              children: [
                SafeArea(
                  child: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: mediaSize.height -
                            mediaPadding.top -
                            mediaPadding.bottom,
                      ),
                      child: IntrinsicHeight(
                        child: Padding(
                          padding: useLiquidGlass
                              ? const EdgeInsets.all(8)
                              : EdgeInsets.zero,
                          child: useLiquidGlass
                              ? Consumer(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(28),
                                    child: _buildNavigationRail(destinations),
                                  ),
                                  builder: (context, ref, child) {
                                    return LiquidGlassContainer(
                                      shape: const LiquidGlassShape
                                          .roundedRectangle(28),
                                      fallbackIntensity: ref.watch(
                                        fallbackGlassTransparencyProvider,
                                      ),
                                      child: child,
                                    );
                                  },
                                )
                              : _buildNavigationRail(destinations),
                        ),
                      ),
                    ),
                  ),
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(
                  child: Consumer(
                    builder: (context, ref, child) {
                      final authState = ref.watch(authProvider);
                      final isOfflineMode = authState.currentUser != null &&
                          !authState.isLoggedIn &&
                          authState.error != null;

                      final pages = PageStorage(
                        bucket: _bucket,
                        child: IndexedStack(
                          index: _currentIndex,
                          children: List.generate(_screens.length, (index) {
                            return HeroMode(
                              enabled: index == _currentIndex,
                              child: _screens[index],
                            );
                          }),
                        ),
                      );
                      final miniPlayer = Consumer(
                        builder: (context, ref, child) {
                          final currentTrack = ref.watch(currentTrackProvider);
                          return currentTrack.when(
                            data: (track) => track != null
                                ? const MiniPlayer()
                                : const SizedBox.shrink(),
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          );
                        },
                      );

                      final content = useLiquidGlass
                          ? LiquidGlassDockOverlay(
                              onExtentChanged: (extent) {
                                if (_liquidDockExtent.value != extent) {
                                  _liquidDockExtent.value = extent;
                                }
                              },
                              dock: AnimatedSize(
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOutCubic,
                                alignment: Alignment.bottomCenter,
                                child: miniPlayer,
                              ),
                              child: pages,
                            )
                          : Column(
                              children: [
                                Expanded(child: pages),
                                miniPlayer,
                              ],
                            );

                      return Padding(
                        padding: EdgeInsets.only(top: isOfflineMode ? 30 : 0),
                        child: SafeArea(
                          top: false,
                          bottom: !useLiquidGlass,
                          child: content,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Consumer(
                builder: (context, ref, child) {
                  final authState = ref.watch(authProvider);
                  final isOfflineMode = authState.currentUser != null &&
                      !authState.isLoggedIn &&
                      authState.error != null;

                  if (!isOfflineMode) return const SizedBox.shrink();
                  final topPadding = MediaQuery.paddingOf(context).top;

                  return Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(12, topPadding + 4, 12, 4),
                    color: Colors.orange.shade800,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.cloud_off,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            S.of(context).offlineModeMessage,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            await ref
                                .read(authProvider.notifier)
                                .retryConnection();
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            S.of(context).retry,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
      return useLiquidGlass
          ? LiquidGlassDockScope(
              notifier: _liquidDockExtent,
              child: landscapeScaffold,
            )
          : landscapeScaffold;
    }

    final miniPlayer = Consumer(
      builder: (context, ref, child) {
        final currentTrack = ref.watch(currentTrackProvider);
        return currentTrack.when(
          data: (track) =>
              track != null ? const MiniPlayer() : const SizedBox.shrink(),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
    );
    final bottomNavigation = Consumer(
      child: miniPlayer,
      builder: (context, ref, child) {
        return MainBottomNavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _handleDestinationSelected,
          destinations: destinations,
          liquidGlass: useLiquidGlass,
          fallbackGlassTransparency:
              ref.watch(fallbackGlassTransparencyProvider),
          showUpdateBadge: showUpdateBadge,
          onLayoutExtentChanged: (extent) {
            if (_liquidDockExtent.value != extent) {
              _liquidDockExtent.value = extent;
            }
          },
          miniPlayer: child!,
        );
      },
    );

    final portraitScaffold = Scaffold(
      body: Stack(
        children: [
          Consumer(
            builder: (context, ref, child) {
              final authState = ref.watch(authProvider);
              final isOfflineMode = authState.currentUser != null &&
                  !authState.isLoggedIn &&
                  authState.error != null;

              return Padding(
                padding: EdgeInsets.only(top: isOfflineMode ? 30 : 0),
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: LiquidGlassDockMediaQuery(
                    child: PageStorage(
                      bucket: _bucket,
                      child: IndexedStack(
                        index: _currentIndex,
                        children: List.generate(_screens.length, (index) {
                          return HeroMode(
                            enabled: index == _currentIndex,
                            child: _screens[index],
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Consumer(
              builder: (context, ref, child) {
                final authState = ref.watch(authProvider);
                final isOfflineMode = authState.currentUser != null &&
                    !authState.isLoggedIn &&
                    authState.error != null;

                if (!isOfflineMode) return const SizedBox.shrink();
                final topPadding = MediaQuery.paddingOf(context).top;

                return Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(12, topPadding + 4, 12, 4),
                  color: Colors.orange.shade800,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.cloud_off,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          S.of(context).offlineModeMessage,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          await ref.read(authProvider.notifier).retryConnection();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          S.of(context).retry,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (useLiquidGlass)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: bottomNavigation,
            ),
        ],
      ),
      bottomNavigationBar: useLiquidGlass ? null : bottomNavigation,
    );
    return useLiquidGlass
        ? LiquidGlassDockScope(
            notifier: _liquidDockExtent,
            child: portraitScaffold,
          )
        : portraitScaffold;
  }

  Widget _buildNavigationRail(List<NavigationDestination> destinations) {
    return NavigationRail(
      selectedIndex: _currentIndex,
      onDestinationSelected: _handleDestinationSelected,
      labelType: NavigationRailLabelType.selected,
      destinations: destinations
          .map(
            (dest) => NavigationRailDestination(
              icon: dest.icon,
              selectedIcon: dest.selectedIcon,
              label: Text(dest.label),
            ),
          )
          .toList(),
    );
  }
}
