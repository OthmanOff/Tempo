import 'dart:convert';
import 'package:agenda_app/core/api/api_client.dart';
import 'package:agenda_app/core/database/app_database.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authTokenProvider = StateProvider<String?>((ref) => null);

enum SyncStatus { idle, syncing, succeeded, failed }

class SyncState {
  const SyncState({
    this.status = SyncStatus.idle,
    this.lastSyncedAt,
    this.error,
  });
  final SyncStatus status;
  final DateTime? lastSyncedAt;
  final Object? error;
}

class SyncEngine extends StateNotifier<SyncState> {
  SyncEngine(this._database, this._client, this._readToken)
    : super(const SyncState());

  final AppDatabase _database;
  final Dio _client;
  final String? Function() _readToken;
  bool _running = false;

  Future<void> synchronize() async {
    if (_running || _readToken() == null) return;
    _running = true;
    state = SyncState(
      status: SyncStatus.syncing,
      lastSyncedAt: state.lastSyncedAt,
    );
    try {
      await _push();
      await _pull();
      final completedAt = DateTime.now().toUtc();
      state = SyncState(
        status: SyncStatus.succeeded,
        lastSyncedAt: completedAt,
      );
    } catch (error) {
      state = SyncState(
        status: SyncStatus.failed,
        lastSyncedAt: state.lastSyncedAt,
        error: error,
      );
      rethrow;
    } finally {
      _running = false;
    }
  }

  Options get _options =>
      Options(headers: {'Authorization': 'Bearer ${_readToken()}'});

  Future<void> _push() async {
    final operations =
        await (_database.select(_database.pendingOperations)
              ..orderBy([(row) => OrderingTerm.asc(row.createdAt)])
              ..limit(100))
            .get();
    if (operations.isEmpty) return;

    late Response<Map<String, dynamic>> response;
    try {
      response = await _client.post<Map<String, dynamic>>(
        '/api/v1/sync/push',
        options: _options,
        data: {
          'operations': operations
              .map(
                (operation) => {
                  'id': operation.id,
                  'operationType': operation.operationType,
                  'entityType': operation.entityType,
                  'entityId': operation.entityId,
                  'payload': jsonDecode(operation.payload),
                  'createdAt': operation.createdAt.toUtc().toIso8601String(),
                },
              )
              .toList(),
        },
      );
    } catch (error) {
      await _database.batch((batch) {
        for (final operation in operations) {
          batch.update(
            _database.pendingOperations,
            PendingOperationsCompanion(
              retryCount: Value(operation.retryCount + 1),
              lastError: Value(error.toString()),
            ),
            where: (row) => row.id.equals(operation.id),
          );
        }
      });
      rethrow;
    }
    final accepted = (response.data?['accepted'] as List<dynamic>? ?? [])
        .cast<String>();
    if (accepted.isNotEmpty) {
      await (_database.delete(
        _database.pendingOperations,
      )..where((row) => row.id.isIn(accepted))).go();
    }
  }

  Future<void> _pull() async {
    final metadata = await (_database.select(
      _database.syncMetadata,
    )..where((row) => row.key.equals('pullCursor'))).getSingleOrNull();
    final response = await _client.get<Map<String, dynamic>>(
      '/api/v1/sync/pull',
      options: _options,
      queryParameters: metadata == null ? null : {'since': metadata.value},
    );
    final body = response.data!;
    final cursor = body['cursor'] as String;
    final changes = (body['changes'] as List<dynamic>)
        .cast<Map<String, dynamic>>();

    await _database.transaction(() async {
      for (final change in changes) {
        await _applyRemote(
          change['entityType'] as String,
          (change['data'] as Map).cast<String, dynamic>(),
        );
      }
      await _database
          .into(_database.syncMetadata)
          .insertOnConflictUpdate(
            SyncMetadataCompanion.insert(key: 'pullCursor', value: cursor),
          );
    });
  }

  Future<void> _applyRemote(
    String entityType,
    Map<String, dynamic> data,
  ) async {
    switch (entityType) {
      case 'project':
        await _database
            .into(_database.projects)
            .insertOnConflictUpdate(
              ProjectsCompanion.insert(
                id: data['id'] as String,
                userId: data['userId'] as String,
                name: data['name'] as String,
                description: Value(data['description'] as String?),
                icon: Value(data['icon'] as String?),
                color: Value(data['color'] as String?),
                archivedAt: Value(_date(data['archivedAt'])),
                createdAt: _date(data['createdAt'])!,
                updatedAt: _date(data['updatedAt'])!,
                deletedAt: Value(_date(data['deletedAt'])),
              ),
            );
      case 'task':
        await _database
            .into(_database.tasks)
            .insertOnConflictUpdate(
              TasksCompanion.insert(
                id: data['id'] as String,
                userId: data['userId'] as String,
                projectId: Value(data['projectId'] as String?),
                parentTaskId: Value(data['parentTaskId'] as String?),
                title: data['title'] as String,
                description: Value(data['description'] as String?),
                status: Value(data['status'] as String),
                priority: Value(data['priority'] as String),
                estimatedDurationMinutes: Value(
                  data['estimatedDurationMinutes'] as int?,
                ),
                dueAt: Value(_date(data['dueAt'])),
                scheduledStartAt: Value(_date(data['scheduledStartAt'])),
                scheduledEndAt: Value(_date(data['scheduledEndAt'])),
                completedAt: Value(_date(data['completedAt'])),
                sortOrder: Value(data['order'] as int? ?? 0),
                createdAt: _date(data['createdAt'])!,
                updatedAt: _date(data['updatedAt'])!,
                deletedAt: Value(_date(data['deletedAt'])),
              ),
            );
      case 'event':
        await _database
            .into(_database.events)
            .insertOnConflictUpdate(
              EventsCompanion.insert(
                id: data['id'] as String,
                userId: data['userId'] as String,
                projectId: Value(data['projectId'] as String?),
                calendarSourceId: Value(data['calendarSourceId'] as String?),
                title: data['title'] as String,
                description: Value(data['description'] as String?),
                location: Value(data['location'] as String?),
                startAt: _date(data['startAt'])!,
                endAt: _date(data['endAt'])!,
                allDay: Value(data['allDay'] as bool),
                recurrenceRule: Value(data['recurrenceRule'] as String?),
                source: Value(data['source'] as String),
                externalId: Value(data['externalId'] as String?),
                createdAt: _date(data['createdAt'])!,
                updatedAt: _date(data['updatedAt'])!,
                deletedAt: Value(_date(data['deletedAt'])),
              ),
            );
      case 'routine':
        await _database
            .into(_database.routines)
            .insertOnConflictUpdate(
              RoutinesCompanion.insert(
                id: data['id'] as String,
                userId: data['userId'] as String,
                projectId: Value(data['projectId'] as String?),
                name: data['name'] as String,
                recurrenceRule: data['recurrenceRule'] as String,
                preferredDurationMinutes:
                    data['preferredDurationMinutes'] as int,
                preferredStartTime: Value(
                  data['preferredStartTime'] as String?,
                ),
                enabled: Value(data['enabled'] as bool),
                createdAt: _date(data['createdAt'])!,
                updatedAt: _date(data['updatedAt'])!,
                deletedAt: Value(_date(data['deletedAt'])),
              ),
            );
      case 'calendar_source':
        await _database
            .into(_database.calendarSources)
            .insertOnConflictUpdate(
              CalendarSourcesCompanion.insert(
                id: data['id'] as String,
                userId: data['userId'] as String,
                name: data['name'] as String,
                type: data['type'] as String,
                url: Value(data['url'] as String?),
                enabled: Value(data['enabled'] as bool),
                lastSyncedAt: Value(_date(data['lastSyncedAt'])),
                createdAt: _date(data['createdAt'])!,
                updatedAt: _date(data['updatedAt'])!,
                deletedAt: Value(_date(data['deletedAt'])),
              ),
            );
      default:
        throw FormatException('Unsupported sync entity: $entityType');
    }
  }

  DateTime? _date(dynamic value) =>
      value == null ? null : DateTime.parse(value as String).toUtc();
}

final syncEngineProvider = StateNotifierProvider<SyncEngine, SyncState>((ref) {
  return SyncEngine(
    ref.watch(appDatabaseProvider),
    ref.watch(apiClientProvider),
    () => ref.read(authTokenProvider),
  );
});
