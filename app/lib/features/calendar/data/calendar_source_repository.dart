import 'package:agenda_app/core/database/app_database.dart';
import 'package:agenda_app/core/sync/sync_queue.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

class CalendarSourceRepository {
  CalendarSourceRepository(this._database, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid(),
      _queue = SyncQueue(_database, uuid: uuid);

  final AppDatabase _database;
  final Uuid _uuid;
  final SyncQueue _queue;

  Stream<List<LocalCalendarSource>> watch(String userId) {
    return (_database.select(_database.calendarSources)
          ..where(
            (source) =>
                source.userId.equals(userId) & source.deletedAt.isNull(),
          )
          ..orderBy([(source) => OrderingTerm.asc(source.name)]))
        .watch();
  }

  Future<String> createUrl({
    required String userId,
    required String name,
    required String url,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasScheme ||
        !{'http', 'https'}.contains(uri.scheme)) {
      throw ArgumentError.value(url, 'url', 'must be an HTTP(S) URL');
    }
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();
    await _database.transaction(() async {
      await _database
          .into(_database.calendarSources)
          .insert(
            CalendarSourcesCompanion.insert(
              id: id,
              userId: userId,
              name: name.trim(),
              type: 'ics_url',
              url: Value(url.trim()),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _queue.enqueue(
        operation: SyncOperationType.create,
        entityType: 'calendar_source',
        entityId: id,
        payload: {
          'id': id,
          'name': name.trim(),
          'type': 'ics_url',
          'url': url.trim(),
          'enabled': true,
          'updatedAt': now.toIso8601String(),
        },
      );
    });
    return id;
  }
}

final calendarSourceRepositoryProvider = Provider<CalendarSourceRepository>(
  (ref) => CalendarSourceRepository(ref.watch(appDatabaseProvider)),
);
