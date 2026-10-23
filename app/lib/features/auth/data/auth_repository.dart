import 'package:agenda_app/core/api/api_client.dart';
import 'package:agenda_app/core/database/app_database.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _tokenKey = 'agenda_access_token';

class AuthSession {
  const AuthSession({required this.token, required this.user});

  final String token;
  final LocalUser user;
}

class AuthRepository {
  AuthRepository(this._client, this._database, this._storage);

  final Dio _client;
  final AppDatabase _database;
  final FlutterSecureStorage _storage;

  Future<AuthSession?> restoreSession() async {
    String? token;
    try {
      token = await _storage.read(key: _tokenKey);
    } catch (_) {
      // Web secure storage requires HTTPS (localhost is the only exception).
      return null;
    }
    if (token == null) return null;

    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/api/v1/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final user = _parseUser(response.data!);
      await _persistUser(user);
      return AuthSession(token: token, user: user);
    } catch (_) {
      return null;
    }
  }

  Future<AuthSession> login(String email, String password) => _authenticate(
    '/api/v1/auth/login',
    {'email': email.trim(), 'password': password},
  );

  Future<AuthSession> register(String name, String email, String password) =>
      _authenticate('/api/v1/auth/register', {
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
      });

  Future<AuthSession> _authenticate(
    String path,
    Map<String, String> payload,
  ) async {
    final response = await _client.post<Map<String, dynamic>>(
      path,
      data: payload,
    );
    final data = response.data!;
    final token = data['token'] as String;
    final user = _parseUser((data['user'] as Map).cast<String, dynamic>());

    // A successful API authentication must not be turned into a login error
    // by a browser persistence failure.
    await _persistUser(user);
    await _persistToken(token);
    return AuthSession(token: token, user: user);
  }

  LocalUser _parseUser(Map<String, dynamic> data) {
    final now = DateTime.now().toUtc();
    return LocalUser(
      id: data['id'] as String,
      email: data['email'] as String,
      name: data['name'] as String,
      timezone: data['timezone'] as String? ?? 'Europe/Paris',
      createdAt: _date(data['createdAt']) ?? now,
      updatedAt: _date(data['updatedAt']) ?? now,
      deletedAt: _date(data['deletedAt']),
    );
  }

  Future<void> _persistUser(LocalUser user) async {
    try {
      await _database.into(_database.users).insertOnConflictUpdate(user);
    } catch (_) {
      // The authenticated user remains available from the in-memory provider.
    }
  }

  Future<void> _persistToken(String token) async {
    try {
      await _storage.write(key: _tokenKey, value: token);
    } catch (_) {
      // The in-memory token remains valid until the page is refreshed.
    }
  }

  Future<void> logout() async {
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {
      // There may be nothing to delete when secure storage is unavailable.
    }
  }

  DateTime? _date(dynamic value) =>
      value is String ? DateTime.tryParse(value)?.toUtc() : null;
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(appDatabaseProvider),
    const FlutterSecureStorage(),
  );
});
