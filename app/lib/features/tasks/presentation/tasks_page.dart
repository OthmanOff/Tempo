import 'package:agenda_app/core/database/app_database.dart';
import 'package:agenda_app/core/theme/app_spacing.dart';
import 'package:agenda_app/core/widgets/empty_state.dart';
import 'package:agenda_app/features/auth/presentation/session_providers.dart';
import 'package:agenda_app/features/tasks/data/task_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TasksPage extends ConsumerStatefulWidget {
  const TasksPage({super.key});
  static const routePath = '/tasks';

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage> {
  TaskListFilter filter = TaskListFilter.all;

  static const labels = {
    TaskListFilter.inbox: 'Inbox',
    TaskListFilter.today: 'Aujourd’hui',
    TaskListFilter.upcoming: 'À venir',
    TaskListFilter.undated: 'Sans date',
    TaskListFilter.completed: 'Terminées',
    TaskListFilter.all: 'Toutes',
  };

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(activeUserProvider).asData?.value;
    return Scaffold(
      appBar: AppBar(title: const Text('Tâches')),
      body: user == null
          ? const EmptyState(
              icon: Icons.person_outline,
              title: 'Aucun profil local',
              message: 'Une session est nécessaire pour afficher vos tâches.',
            )
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: labels.entries
                          .map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(entry.value),
                                selected: filter == entry.key,
                                onSelected: (_) =>
                                    setState(() => filter = entry.key),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: StreamBuilder<List<LocalTask>>(
                      stream: ref
                          .watch(taskRepositoryProvider)
                          .watchTasks(userId: user.id, filter: filter),
                      builder: (context, snapshot) {
                        final tasks = snapshot.data ?? const [];
                        if (tasks.isEmpty) {
                          return const EmptyState(
                            icon: Icons.check_circle_outline,
                            title: 'Aucune tâche',
                            message:
                                'Les tâches correspondant à ce filtre apparaîtront ici.',
                          );
                        }
                        return ListView.separated(
                          itemCount: tasks.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final task = tasks[index];
                            return ListTile(
                              minVerticalPadding: 12,
                              leading: Checkbox(
                                value: task.status == 'completed',
                                onChanged: (value) => ref
                                    .read(taskRepositoryProvider)
                                    .markCompleted(
                                      task.id,
                                      completed: value ?? false,
                                    ),
                              ),
                              title: Text(task.title),
                              subtitle: Text(_metadata(task)),
                              trailing: _PriorityDot(priority: task.priority),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _metadata(LocalTask task) {
    final parts = <String>[];
    if (task.estimatedDurationMinutes != null) {
      parts.add('${task.estimatedDurationMinutes} min');
    }
    if (task.dueAt != null) {
      parts.add(MaterialLocalizations.of(context).formatShortDate(task.dueAt!));
    }
    return parts.isEmpty ? 'Sans date' : parts.join(' · ');
  }
}

class _PriorityDot extends StatelessWidget {
  const _PriorityDot({required this.priority});
  final String priority;

  @override
  Widget build(BuildContext context) {
    final color = switch (priority) {
      'urgent' => Colors.red,
      'high' => Colors.orange,
      'medium' => Colors.amber,
      'low' => Colors.blue,
      _ => Theme.of(context).colorScheme.outlineVariant,
    };
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
