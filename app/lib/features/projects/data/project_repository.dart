import 'package:agenda_app/core/database/app_database.dart';
import 'package:agenda_app/core/sync/sync_queue.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

class ProjectRepository {
  ProjectRepository(this._database, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid(),
      _queue = SyncQueue(_database, uuid: uuid);

  final AppDatabase _database;
  final Uuid _uuid;
  final SyncQueue _queue;

  Stream<List<LocalProject>> watchProjects(String userId) {
    final query = _database.select(_database.projects)
      ..where(
        (project) =>
            project.userId.equals(userId) &
            project.deletedAt.isNull() &
            project.archivedAt.isNull(),
      )
      ..orderBy([(project) => OrderingTerm.asc(project.name)]);
    return query.watch();
  }

  Future<String> create({required String userId, required String name}) async {
    final id = _uuid.v4();
    final timestamp = DateTime.now().toUtc();
    await _database.transaction(() async {
      await _database
          .into(_database.projects)
          .insert(
            ProjectsCompanion.insert(
              id: id,
              userId: userId,
              name: name.trim(),
              createdAt: timestamp,
              updatedAt: timestamp,
            ),
          );
      await _queue.enqueue(
        operation: SyncOperationType.create,
        entityType: 'project',
        entityId: id,
        payload: {
          'id': id,
          'name': name.trim(),
          'updatedAt': timestamp.toIso8601String(),
        },
      );
    });
    return id;
  }
}

final projectRepositoryProvider = Provider<ProjectRepository>(
  (ref) => ProjectRepository(ref.watch(appDatabaseProvider)),
);
