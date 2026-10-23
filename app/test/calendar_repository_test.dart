import 'package:agenda_app/core/database/app_database.dart';
import 'package:agenda_app/features/calendar/data/calendar_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late CalendarRepository repository;
  const userId = '0199a6d5-e506-7e3e-8f5f-775f3442bd24';

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = CalendarRepository(database);
    final now = DateTime.utc(2026, 10, 4);
    await database
        .into(database.users)
        .insert(
          UsersCompanion.insert(
            id: userId,
            email: 'owner@example.test',
            name: 'Owner',
            createdAt: now,
            updatedAt: now,
          ),
        );
  });

  tearDown(() => database.close());

  test('creates an event and queues it for synchronization', () async {
    final event = await repository.createEvent(
      userId: userId,
      title: '  Rendez-vous dentiste  ',
      startAt: DateTime.utc(2026, 10, 24, 9),
      endAt: DateTime.utc(2026, 10, 24, 10),
      location: 'Cabinet',
    );
    final operations = await database.select(database.pendingOperations).get();

    expect(event.title, 'Rendez-vous dentiste');
    expect(event.location, 'Cabinet');
    expect(operations, hasLength(1));
    expect(operations.single.entityType, 'event');
    expect(operations.single.entityId, event.id);
  });

  test('refuses an event ending before it starts', () async {
    expect(
      () => repository.createEvent(
        userId: userId,
        title: 'Invalide',
        startAt: DateTime.utc(2026, 10, 24, 10),
        endAt: DateTime.utc(2026, 10, 24, 9),
      ),
      throwsArgumentError,
    );
  });
}
