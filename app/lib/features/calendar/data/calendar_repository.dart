import 'package:agenda_app/core/database/app_database.dart';
import 'package:agenda_app/core/sync/sync_queue.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

class CalendarRepository {
  CalendarRepository(this._database, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid(),
      _queue = SyncQueue(_database, uuid: uuid);
  final AppDatabase _database;
  final Uuid _uuid;
  final SyncQueue _queue;

  Future<LocalEvent> createEvent({
    required String userId,
    required String title,
    required DateTime startAt,
    required DateTime endAt,
    String? description,
    String? location,
    bool allDay = false,
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) throw ArgumentError('Le titre est obligatoire.');
    if (!endAt.isAfter(startAt)) {
      throw ArgumentError('La fin doit être après le début.');
    }

    final id = _uuid.v4();
    final timestamp = DateTime.now().toUtc();
    final start = startAt.toUtc();
    final end = endAt.toUtc();
    final cleanDescription = description?.trim();
    final cleanLocation = location?.trim();
    await _database.transaction(() async {
      await _database
          .into(_database.events)
          .insert(
            EventsCompanion.insert(
              id: id,
              userId: userId,
              title: cleanTitle,
              description: Value(
                cleanDescription?.isEmpty == true ? null : cleanDescription,
              ),
              location: Value(
                cleanLocation?.isEmpty == true ? null : cleanLocation,
              ),
              startAt: start,
              endAt: end,
              allDay: Value(allDay),
              createdAt: timestamp,
              updatedAt: timestamp,
            ),
          );
      await _queue.enqueue(
        operation: SyncOperationType.create,
        entityType: 'event',
        entityId: id,
        payload: {
          'id': id,
          'title': cleanTitle,
          'description': cleanDescription?.isEmpty == true
              ? null
              : cleanDescription,
          'location': cleanLocation?.isEmpty == true ? null : cleanLocation,
          'startAt': start.toIso8601String(),
          'endAt': end.toIso8601String(),
          'allDay': allDay,
          'source': 'local',
          'updatedAt': timestamp.toIso8601String(),
        },
      );
    });
    return (_database.select(
      _database.events,
    )..where((row) => row.id.equals(id))).getSingle();
  }

  Stream<List<LocalEvent>> watchEvents({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) {
    final query = _database.select(_database.events)
      ..where(
        (event) =>
            event.userId.equals(userId) &
            event.deletedAt.isNull() &
            event.startAt.isSmallerThanValue(to.toUtc()) &
            event.endAt.isBiggerThanValue(from.toUtc()),
      )
      ..orderBy([(event) => OrderingTerm.asc(event.startAt)]);
    return query.watch();
  }

  Stream<List<LocalTask>> watchScheduledTasks({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) {
    final query = _database.select(_database.tasks)
      ..where(
        (task) =>
            task.userId.equals(userId) &
            task.deletedAt.isNull() &
            task.scheduledStartAt.isSmallerThanValue(to.toUtc()) &
            task.scheduledEndAt.isBiggerThanValue(from.toUtc()),
      )
      ..orderBy([(task) => OrderingTerm.asc(task.scheduledStartAt)]);
    return query.watch();
  }
}

final calendarRepositoryProvider = Provider<CalendarRepository>(
  (ref) => CalendarRepository(ref.watch(appDatabaseProvider)),
);
