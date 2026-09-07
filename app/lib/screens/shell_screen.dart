import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/core/widgets/max_width.dart';
import 'package:nemo/core/widgets/nemo_mark.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/router.dart';

/// Adaptive chrome around the main destinations: a bottom navigation bar on
/// phones, a navigation rail from 840 dp. Content is centred and capped so
/// the web app reads like the phone app.
class ShellScreen extends StatelessWidget {
  const ShellScreen({required this.child, super.key});

  final Widget child;

  static const railBreakpoint = 840.0;

  static List<
    ({IconData icon, IconData selectedIcon, String label, String path})
  >
  destinations(BuildContext context) {
    final l = L.of(context);
    return [
      (
        icon: Icons.today_outlined,
        selectedIcon: Icons.today,
        label: l.navToday,
        path: Routes.today,
      ),
      (
        icon: Icons.event_outlined,
        selectedIcon: Icons.event,
        label: l.navUpcoming,
        path: Routes.upcoming,
      ),
      (
        icon: Icons.folder_outlined,
        selectedIcon: Icons.folder,
        label: l.navLists,
        path: Routes.lists,
      ),
      (
        icon: Icons.search_outlined,
        selectedIcon: Icons.search,
        label: l.navSearch,
        path: Routes.search,
      ),
    ];
  }

  static int indexFor(String location) {
    if (location.startsWith(Routes.today)) return 0;
    if (location.startsWith(Routes.upcoming)) return 1;
    if (location.startsWith(Routes.lists)) return 2;
    if (location.startsWith(Routes.search)) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final items = destinations(context);
    final index = indexFor(GoRouterState.of(context).matchedLocation);
    final wide = MediaQuery.sizeOf(context).width >= railBreakpoint;
    void go(int i) => context.go(items[i].path);

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: index,
              onDestinationSelected: go,
              groupAlignment: -0.9,
              leading: const Padding(
                padding: EdgeInsets.only(top: 8, bottom: 16),
                child: NemoLogoTile(),
              ),
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: IconButton(
                      tooltip: L.of(context).navSettings,
                      icon: const Icon(Icons.settings_outlined),
                      onPressed: () => context.push(Routes.settings),
                    ),
                  ),
                ),
              ),
              destinations: [
                for (final d in items)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: MaxWidth(child: child)),
          ],
        ),
      );
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: go,
        destinations: [
          for (final d in items)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}
