import 'dart:convert';
import 'package:agenda_app/core/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

enum SyncOperationType { create, update, delete }

class SyncQueue {
  SyncQueue(this._database, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final Uuid _uuid;

  Future<void> enqueue({
    required SyncOperationType operation,
    required String entityType,
    required String entityId,
    required Map<String, Object?> payload,
  }) {
    return _database
        .into(_database.pendingOperations)
        .insert(
          PendingOperationsCompanion.insert(
            id: _uuid.v4(),
            operationType: operation.name,
            entityType: entityType,
            entityId: entityId,
            payload: jsonEncode(payload),
            createdAt: DateTime.now().toUtc(),
          ),
        );
  }

  Stream<List<PendingOperation>> watchPending() => (_database.select(
    _database.pendingOperations,
  )..orderBy([(row) => OrderingTerm.asc(row.createdAt)])).watch();
}
