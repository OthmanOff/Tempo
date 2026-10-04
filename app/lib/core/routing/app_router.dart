import 'package:agenda_app/app/app_shell.dart';
import 'package:agenda_app/features/calendar/presentation/calendar_page.dart';
import 'package:agenda_app/features/auth/presentation/login_page.dart';
import 'package:agenda_app/features/projects/presentation/projects_page.dart';
import 'package:agenda_app/features/settings/presentation/settings_page.dart';
import 'package:agenda_app/features/tasks/presentation/tasks_page.dart';
import 'package:agenda_app/features/today/presentation/today_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: LoginPage.routePath,
    routes: [
      GoRoute(path: LoginPage.routePath, builder: (_, __) => const LoginPage()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: TodayPage.routePath,
                builder: (_, __) => const TodayPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: CalendarPage.routePath,
                builder: (_, __) => const CalendarPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: TasksPage.routePath,
                builder: (_, __) => const TasksPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: ProjectsPage.routePath,
                builder: (_, __) => const ProjectsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: SettingsPage.routePath,
                builder: (_, __) => const SettingsPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
