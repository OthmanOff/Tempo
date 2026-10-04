import 'package:agenda_app/core/database/app_database.dart';
import 'package:agenda_app/core/theme/app_spacing.dart';
import 'package:agenda_app/core/widgets/empty_state.dart';
import 'package:agenda_app/features/auth/presentation/session_providers.dart';
import 'package:agenda_app/features/today/presentation/today_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class TodayPage extends ConsumerWidget {
  const TodayPage({super.key});

  static const routeName = 'today';
  static const routePath = '/today';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(activeUserProvider).asData?.value;
    final tasks =
        ref.watch(todayTasksProvider).valueOrNull ?? const <LocalTask>[];
    final events =
        ref.watch(todayEventsProvider).valueOrNull ?? const <LocalEvent>[];
    final inbox =
        ref.watch(inboxTasksProvider).valueOrNull ?? const <LocalTask>[];
    final projects =
        ref.watch(activeProjectsProvider).valueOrNull ?? const <LocalProject>[];
    final date = DateFormat.yMMMMEEEEd('fr_FR').format(DateTime.now());

    return Scaffold(
      body: SafeArea(
        child: user == null
            ? const EmptyState(
                icon: Icons.person_outline,
                title: 'Aucun profil local',
                message:
                    'Connectez votre compte pour commencer à organiser votre journée.',
              )
            : CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      AppSpacing.page,
                      AppSpacing.page,
                      12,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bonjour ${user.name}',
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            date,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 20),
                          _ProgressCard(tasks: tasks),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.page,
                    ),
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.crossAxisExtent >= 760;
                        final sections = [
                          _DayTimeline(tasks: tasks, events: events),
                          _SideColumn(inbox: inbox, projects: projects),
                        ];
                        return SliverToBoxAdapter(
                          child: wide
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(flex: 2, child: sections[0]),
                                    const SizedBox(width: 20),
                                    Expanded(child: sections[1]),
                                  ],
                                )
                              : Column(
                                  children: [
                                    sections[0],
                                    const SizedBox(height: 20),
                                    sections[1],
                                  ],
                                ),
                        );
                      },
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.tasks});
  final List<LocalTask> tasks;

  @override
  Widget build(BuildContext context) {
    final completed = tasks.where((task) => task.status == 'completed').length;
    final progress = tasks.isEmpty ? 0.0 : completed / tasks.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              height: 52,
              child: CircularProgressIndicator(value: progress, strokeWidth: 6),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$completed / ${tasks.length} tâches terminées',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Progression du jour',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DayTimeline extends StatelessWidget {
  const _DayTimeline({required this.tasks, required this.events});
  final List<LocalTask> tasks;
  final List<LocalEvent> events;

  @override
  Widget build(BuildContext context) {
    final items = <({DateTime start, String title, IconData icon})>[
      ...events.map(
        (event) =>
            (start: event.startAt, title: event.title, icon: Icons.event),
      ),
      ...tasks
          .where((task) => task.scheduledStartAt != null)
          .map(
            (task) => (
              start: task.scheduledStartAt!,
              title: task.title,
              icon: Icons.task_alt,
            ),
          ),
    ]..sort((a, b) => a.start.compareTo(b.start));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Aujourd’hui', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Card(
          child: items.isEmpty
              ? const SizedBox(
                  height: 220,
                  child: EmptyState(
                    icon: Icons.calendar_today_outlined,
                    title: 'Journée libre',
                    message: 'Aucune activité planifiée aujourd’hui.',
                  ),
                )
              : Column(
                  children: items
                      .map(
                        (item) => ListTile(
                          leading: Text(
                            DateFormat.Hm().format(item.start),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          title: Text(item.title),
                          trailing: Icon(item.icon),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }
}

class _SideColumn extends StatelessWidget {
  const _SideColumn({required this.inbox, required this.projects});
  final List<LocalTask> inbox;
  final List<LocalProject> projects;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('À planifier', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Card(
          child: inbox.isEmpty
              ? const ListTile(
                  title: Text('Inbox vide'),
                  leading: Icon(Icons.inbox_outlined),
                )
              : Column(
                  children: inbox
                      .take(5)
                      .map(
                        (task) => ListTile(
                          title: Text(task.title),
                          leading: const Icon(Icons.circle_outlined),
                        ),
                      )
                      .toList(),
                ),
        ),
        const SizedBox(height: 20),
        Text('Projets', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Card(
          child: projects.isEmpty
              ? const ListTile(
                  title: Text('Aucun projet'),
                  leading: Icon(Icons.folder_outlined),
                )
              : Column(
                  children: projects
                      .take(5)
                      .map(
                        (project) => ListTile(
                          title: Text(project.name),
                          leading: const Icon(Icons.folder_outlined),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }
}
