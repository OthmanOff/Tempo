import 'dart:convert';
import 'dart:typed_data';
import 'package:agenda_app/core/api/api_client.dart';
import 'package:agenda_app/core/sync/sync_engine.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class IcsApiService {
  IcsApiService(this._client, this._token);
  final Dio _client;
  final String? Function() _token;

  Options get _options {
    final token = _token();
    if (token == null) throw StateError('Authentication required');
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<void> importFile({
    required String name,
    required Uint8List bytes,
  }) async {
    await _client.post<void>(
      '/api/v1/calendar-sources/import',
      options: _options,
      data: {'name': name, 'content': utf8.decode(bytes)},
    );
  }

  Future<void> syncSource(String id) async {
    await _client.post<void>(
      '/api/v1/calendar-sources/$id/sync',
      options: _options,
    );
  }
}

final icsApiServiceProvider = Provider<IcsApiService>((ref) {
  return IcsApiService(
    ref.watch(apiClientProvider),
    () => ref.read(authTokenProvider),
  );
});
