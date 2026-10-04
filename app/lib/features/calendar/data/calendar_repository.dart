import 'package:agenda_app/core/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CalendarRepository {
  CalendarRepository(this._database);
  final AppDatabase _database;

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
