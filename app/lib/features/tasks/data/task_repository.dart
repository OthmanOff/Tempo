import 'package:agenda_app/core/database/app_database.dart';
import 'package:agenda_app/core/sync/sync_queue.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

enum TaskListFilter { inbox, today, upcoming, undated, completed, all }

class TaskRepository {
  TaskRepository(this._database, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid(),
      _queue = SyncQueue(_database, uuid: uuid);

  final AppDatabase _database;
  final Uuid _uuid;
  final SyncQueue _queue;

  Stream<List<LocalTask>> watchTasks({
    required String userId,
    TaskListFilter filter = TaskListFilter.all,
    String? projectId,
    String? priority,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final start = DateTime(current.year, current.month, current.day).toUtc();
    final end = start.add(const Duration(days: 1));
    final query = _database.select(_database.tasks)
      ..where((task) => task.userId.equals(userId) & task.deletedAt.isNull());

    if (projectId != null) {
      query.where((task) => task.projectId.equals(projectId));
    }
    if (priority != null) {
      query.where((task) => task.priority.equals(priority));
    }
    switch (filter) {
      case TaskListFilter.inbox:
        query.where((task) => task.status.equals('inbox'));
      case TaskListFilter.today:
        query.where(
          (task) =>
              task.scheduledStartAt.isBiggerOrEqualValue(start) &
              task.scheduledStartAt.isSmallerThanValue(end),
        );
      case TaskListFilter.upcoming:
        query.where((task) => task.scheduledStartAt.isBiggerOrEqualValue(end));
      case TaskListFilter.undated:
        query.where(
          (task) => task.dueAt.isNull() & task.scheduledStartAt.isNull(),
        );
      case TaskListFilter.completed:
        query.where((task) => task.status.equals('completed'));
      case TaskListFilter.all:
        break;
    }

    query.orderBy([
      (task) => OrderingTerm.asc(task.sortOrder),
      (task) => OrderingTerm.desc(task.createdAt),
    ]);
    return query.watch();
  }

  Future<LocalTask> createInboxTask({
    required String userId,
    required String title,
    String? description,
  }) => createTask(userId: userId, title: title, description: description);

  Future<LocalTask> createTask({
    required String userId,
    required String title,
    String? description,
    int? estimatedDurationMinutes,
    DateTime? scheduledStartAt,
  }) async {
    final id = _uuid.v4();
    final timestamp = DateTime.now().toUtc();
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw ArgumentError.value(title, 'title', 'must not be empty');
    }

    final start = scheduledStartAt?.toUtc();
    final end = start?.add(Duration(minutes: estimatedDurationMinutes ?? 30));
    final status = start == null ? 'inbox' : 'scheduled';

    await _database.transaction(() async {
      await _database
          .into(_database.tasks)
          .insert(
            TasksCompanion.insert(
              id: id,
              userId: userId,
              title: normalizedTitle,
              description: Value(description?.trim()),
              status: Value(status),
              estimatedDurationMinutes: Value(estimatedDurationMinutes),
              scheduledStartAt: Value(start),
              scheduledEndAt: Value(end),
              createdAt: timestamp,
              updatedAt: timestamp,
            ),
          );
      await _queue.enqueue(
        operation: SyncOperationType.create,
        entityType: 'task',
        entityId: id,
        payload: {
          'id': id,
          'title': normalizedTitle,
          'description': description?.trim(),
          'status': status,
          'priority': 'none',
          'estimatedDurationMinutes': estimatedDurationMinutes,
          'scheduledStartAt': start?.toIso8601String(),
          'scheduledEndAt': end?.toIso8601String(),
          'createdAt': timestamp.toIso8601String(),
          'updatedAt': timestamp.toIso8601String(),
        },
      );
    });
    return (_database.select(
      _database.tasks,
    )..where((task) => task.id.equals(id))).getSingle();
  }

  Future<void> schedule({
    required String id,
    required DateTime start,
    int? durationMinutes,
    DateTime? end,
  }) async {
    final finish = end ?? start.add(Duration(minutes: durationMinutes ?? 30));
    if (!finish.isAfter(start)) {
      throw ArgumentError('The scheduled end must be after the start');
    }
    await _updateTask(
      id,
      TasksCompanion(
        scheduledStartAt: Value(start.toUtc()),
        scheduledEndAt: Value(finish.toUtc()),
        status: const Value('scheduled'),
        estimatedDurationMinutes: durationMinutes == null
            ? const Value.absent()
            : Value(durationMinutes),
      ),
      {
        'scheduledStartAt': start.toUtc(),
        'scheduledEndAt': finish.toUtc(),
        'status': 'scheduled',
        if (durationMinutes != null)
          'estimatedDurationMinutes': durationMinutes,
      },
    );
  }

  Future<void> moveToInbox(String id) => _updateTask(
    id,
    const TasksCompanion(
      scheduledStartAt: Value(null),
      scheduledEndAt: Value(null),
      status: Value('inbox'),
    ),
    {'scheduledStartAt': null, 'scheduledEndAt': null, 'status': 'inbox'},
  );

  Future<void> markCompleted(String id, {bool completed = true}) {
    final completedAt = completed ? DateTime.now().toUtc() : null;
    return _updateTask(
      id,
      TasksCompanion(
        status: Value(completed ? 'completed' : 'todo'),
        completedAt: Value(completedAt),
      ),
      {'status': completed ? 'completed' : 'todo', 'completedAt': completedAt},
    );
  }

  Future<void> _updateTask(
    String id,
    TasksCompanion changes,
    Map<String, Object?> payload,
  ) async {
    final updatedAt = DateTime.now().toUtc();
    await _database.transaction(() async {
      final affected =
          await (_database.update(_database.tasks)
                ..where((task) => task.id.equals(id)))
              .write(changes.copyWith(updatedAt: Value(updatedAt)));
      if (affected != 1) throw StateError('Task $id was not found');
      await _queue.enqueue(
        operation: SyncOperationType.update,
        entityType: 'task',
        entityId: id,
        payload: {
          ...payload.map(
            (key, value) => MapEntry(
              key,
              value is DateTime ? value.toIso8601String() : value,
            ),
          ),
          'updatedAt': updatedAt.toIso8601String(),
        },
      );
    });
  }
}

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => TaskRepository(ref.watch(appDatabaseProvider)),
);
