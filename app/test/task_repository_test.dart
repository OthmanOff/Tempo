import 'package:agenda_app/core/database/app_database.dart';
import 'package:agenda_app/features/tasks/data/task_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late TaskRepository repository;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = TaskRepository(database);
    final now = DateTime.utc(2026, 10, 4);
    await database
        .into(database.users)
        .insert(
          UsersCompanion.insert(
            id: '0199a6d5-e506-7e3e-8f5f-775f3442bd24',
            email: 'owner@example.test',
            name: 'Owner',
            createdAt: now,
            updatedAt: now,
          ),
        );
  });

  tearDown(() => database.close());

  test('creates an inbox task and queues the same local mutation', () async {
    final task = await repository.createInboxTask(
      userId: '0199a6d5-e506-7e3e-8f5f-775f3442bd24',
      title: '  Appeler assurance  ',
    );
    final operations = await database.select(database.pendingOperations).get();

    expect(task.title, 'Appeler assurance');
    expect(task.status, 'inbox');
    expect(operations, hasLength(1));
    expect(operations.single.entityId, task.id);
    expect(operations.single.operationType, 'create');
  });

  test(
    'schedules a task using its requested duration and queues an update',
    () async {
      final task = await repository.createInboxTask(
        userId: '0199a6d5-e506-7e3e-8f5f-775f3442bd24',
        title: 'Faire le rapport',
      );
      final start = DateTime.utc(2026, 10, 5, 15);

      await repository.schedule(id: task.id, start: start, durationMinutes: 90);
      final scheduled = await (database.select(
        database.tasks,
      )..where((row) => row.id.equals(task.id))).getSingle();
      final operations = await database
          .select(database.pendingOperations)
          .get();

      expect(scheduled.status, 'scheduled');
      expect(scheduled.scheduledStartAt?.toUtc(), start);
      expect(
        scheduled.scheduledEndAt?.toUtc(),
        DateTime.utc(2026, 10, 5, 16, 30),
      );
      expect(operations, hasLength(2));
      expect(operations.last.operationType, 'update');
    },
  );

  test('moves a scheduled task back to inbox and can complete it', () async {
    final task = await repository.createTask(
      userId: '0199a6d5-e506-7e3e-8f5f-775f3442bd24',
      title: 'Préparer le cours',
      scheduledStartAt: DateTime.utc(2026, 10, 5, 9),
      estimatedDurationMinutes: 60,
    );

    await repository.moveToInbox(task.id);
    var updated = await (database.select(
      database.tasks,
    )..where((row) => row.id.equals(task.id))).getSingle();
    expect(updated.status, 'inbox');
    expect(updated.scheduledStartAt, isNull);
    expect(updated.scheduledEndAt, isNull);

    await repository.markCompleted(task.id);
    updated = await (database.select(
      database.tasks,
    )..where((row) => row.id.equals(task.id))).getSingle();
    expect(updated.status, 'completed');
    expect(updated.completedAt, isNotNull);
  });
}
