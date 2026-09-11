import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/core/router/transitions.dart';
import 'package:nemo/features/auth/ui/account_screen.dart';
import 'package:nemo/features/auth/ui/starting_screen.dart';
import 'package:nemo/features/lists/ui/list_detail_screen.dart';
import 'package:nemo/features/lists/ui/lists_screen.dart';
import 'package:nemo/features/lists/ui/members_screen.dart';
import 'package:nemo/features/settings/ui/settings_screen.dart';
import 'package:nemo/features/tasks/ui/search_screen.dart';
import 'package:nemo/features/tasks/ui/task_detail_screen.dart';
import 'package:nemo/features/tasks/ui/today_screen.dart';
import 'package:nemo/features/tasks/ui/upcoming_screen.dart';
import 'package:nemo/screens/shell_screen.dart';

abstract final class Routes {
  static const today = '/today';
  static const upcoming = '/upcoming';
  static const lists = '/lists';
  static const search = '/search';
  static const settings = '/settings';
  static const account = '/settings/account';

  /// Where the web app waits while it looks for a stored session, and
  /// where it sends anyone it does not find one for.
  static const starting = '/starting';
  static const signIn = '/sign-in';
  static String list(String id) => '/lists/$id';
  static String members(String id) => '/lists/$id/members';
  static String task(String id) => '/tasks/$id';
}

abstract final class AppRouter {
  static GoRouter router({
    String initialLocation = Routes.today,
    GoRouterRedirect? redirect,
    Listenable? refreshListenable,
  }) => GoRouter(
    initialLocation: initialLocation,
    redirect: redirect,
    refreshListenable: refreshListenable,
    routes: [
      GoRoute(
        path: Routes.starting,
        pageBuilder: (_, s) =>
            fadeThroughPage(child: const StartingScreen(), state: s),
      ),
      GoRoute(
        path: Routes.signIn,
        pageBuilder: (_, s) => fadeThroughPage(
          child: const AccountScreen(standalone: true),
          state: s,
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => ShellScreen(child: child),
        routes: [
          GoRoute(
            path: Routes.today,
            pageBuilder: (_, s) =>
                fadeThroughPage(child: const TodayScreen(), state: s),
          ),
          GoRoute(
            path: Routes.upcoming,
            pageBuilder: (_, s) =>
                fadeThroughPage(child: const UpcomingScreen(), state: s),
          ),
          GoRoute(
            path: Routes.lists,
            pageBuilder: (_, s) =>
                fadeThroughPage(child: const ListsScreen(), state: s),
          ),
          GoRoute(
            path: '/lists/:id',
            pageBuilder: (_, s) => fadeThroughPage(
              child: ListDetailScreen(listId: s.pathParameters['id']!),
              state: s,
            ),
          ),
          GoRoute(
            path: Routes.search,
            pageBuilder: (_, s) =>
                fadeThroughPage(child: const SearchScreen(), state: s),
          ),
        ],
      ),
      GoRoute(
        path: '/tasks/:id',
        pageBuilder: (_, s) => fadeThroughPage(
          child: TaskDetailScreen(taskId: s.pathParameters['id']!),
          state: s,
        ),
      ),
      GoRoute(
        path: '/lists/:id/members',
        pageBuilder: (_, s) => fadeThroughPage(
          child: MembersScreen(listId: s.pathParameters['id']!),
          state: s,
        ),
      ),
      GoRoute(
        path: Routes.settings,
        pageBuilder: (_, s) =>
            fadeThroughPage(child: const SettingsScreen(), state: s),
        routes: [
          GoRoute(
            path: 'account',
            pageBuilder: (_, s) =>
                fadeThroughPage(child: const AccountScreen(), state: s),
          ),
        ],
      ),
    ],
  );
}
