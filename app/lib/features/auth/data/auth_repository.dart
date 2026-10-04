import 'package:agenda_app/core/api/api_client.dart';
import 'package:agenda_app/core/database/app_database.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _tokenKey = 'agenda_access_token';

class AuthRepository {
  AuthRepository(this._client, this._database, this._storage);

  final Dio _client;
  final AppDatabase _database;
  final FlutterSecureStorage _storage;

  Future<String?> restoreToken() => _storage.read(key: _tokenKey);

  Future<String> login(String email, String password) => _authenticate(
    '/api/v1/auth/login',
    {'email': email.trim(), 'password': password},
  );

  Future<String> register(String name, String email, String password) =>
      _authenticate('/api/v1/auth/register', {
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
      });

  Future<String> _authenticate(String path, Map<String, String> payload) async {
    final response = await _client.post<Map<String, dynamic>>(
      path,
      data: payload,
    );
    final data = response.data!;
    final token = data['token'] as String;
    final user = (data['user'] as Map).cast<String, dynamic>();
    final now = DateTime.now().toUtc();
    await _database
        .into(_database.users)
        .insertOnConflictUpdate(
          UsersCompanion.insert(
            id: user['id'] as String,
            email: user['email'] as String,
            name: user['name'] as String,
            timezone: Value(user['timezone'] as String? ?? 'Europe/Paris'),
            createdAt: _date(user['createdAt']) ?? now,
            updatedAt: _date(user['updatedAt']) ?? now,
            deletedAt: Value(_date(user['deletedAt'])),
          ),
        );
    await _storage.write(key: _tokenKey, value: token);
    return token;
  }

  Future<void> logout() => _storage.delete(key: _tokenKey);

  DateTime? _date(dynamic value) =>
      value == null ? null : DateTime.parse(value as String).toUtc();
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(appDatabaseProvider),
    const FlutterSecureStorage(),
  );
});
