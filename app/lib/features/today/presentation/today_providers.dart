import 'package:agenda_app/core/database/app_database.dart';
import 'package:agenda_app/core/utils/date_ranges.dart';
import 'package:agenda_app/features/auth/presentation/session_providers.dart';
import 'package:agenda_app/features/calendar/data/calendar_repository.dart';
import 'package:agenda_app/features/projects/data/project_repository.dart';
import 'package:agenda_app/features/tasks/data/task_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

String? _userId(Ref ref) => ref.watch(activeUserProvider).asData?.value?.id;

final todayTasksProvider = StreamProvider.autoDispose<List<LocalTask>>((ref) {
  final userId = _userId(ref);
  if (userId == null) return Stream.value(const []);
  return ref
      .watch(taskRepositoryProvider)
      .watchTasks(userId: userId, filter: TaskListFilter.today);
});

final inboxTasksProvider = StreamProvider.autoDispose<List<LocalTask>>((ref) {
  final userId = _userId(ref);
  if (userId == null) return Stream.value(const []);
  return ref
      .watch(taskRepositoryProvider)
      .watchTasks(userId: userId, filter: TaskListFilter.inbox);
});

final todayEventsProvider = StreamProvider.autoDispose<List<LocalEvent>>((ref) {
  final userId = _userId(ref);
  if (userId == null) return Stream.value(const []);
  final range = localDayRange(DateTime.now());
  return ref
      .watch(calendarRepositoryProvider)
      .watchEvents(userId: userId, from: range.start, to: range.end);
});

final activeProjectsProvider = StreamProvider.autoDispose<List<LocalProject>>((
  ref,
) {
  final userId = _userId(ref);
  if (userId == null) return Stream.value(const []);
  return ref.watch(projectRepositoryProvider).watchProjects(userId);
});
