import 'package:agenda_app/core/database/app_database.dart';
import 'package:agenda_app/core/sync/sync_engine.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late AppDatabase database;
  late MockDio client;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    client = MockDio();
  });

  tearDown(() => database.close());

  test(
    'pushes pending operations, removes acknowledgements, then stores pull cursor',
    () async {
      final createdAt = DateTime.utc(2026, 10, 4, 10);
      await database
          .into(database.pendingOperations)
          .insert(
            PendingOperationsCompanion.insert(
              id: '0199a6d5-e506-7e3e-8f5f-775f3442bd20',
              operationType: 'create',
              entityType: 'task',
              entityId: '0199a6d5-e506-7e3e-8f5f-775f3442bd21',
              payload: '{"title":"Test"}',
              createdAt: createdAt,
            ),
          );
      when(
        () => client.post<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(),
          data: {
            'accepted': ['0199a6d5-e506-7e3e-8f5f-775f3442bd20'],
          },
        ),
      );
      when(
        () => client.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(),
          data: {'cursor': '2026-10-04T10:01:00.000Z', 'changes': <dynamic>[]},
        ),
      );

      final engine = SyncEngine(database, client, () => 'token');
      await engine.synchronize();

      expect(await database.select(database.pendingOperations).get(), isEmpty);
      final cursor = await database.select(database.syncMetadata).getSingle();
      expect(cursor.value, '2026-10-04T10:01:00.000Z');
      expect(engine.state.status, SyncStatus.succeeded);
    },
  );
}
