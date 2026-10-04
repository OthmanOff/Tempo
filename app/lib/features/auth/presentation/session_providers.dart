import 'package:agenda_app/core/database/app_database.dart';
import 'package:agenda_app/core/sync/sync_engine.dart';
import 'package:agenda_app/features/auth/data/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final activeUserProvider = StreamProvider<LocalUser?>((ref) {
  final database = ref.watch(appDatabaseProvider);
  return (database.select(database.users)..limit(1)).watchSingleOrNull();
});

class SessionController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final token = await ref.read(authRepositoryProvider).restoreToken();
    ref.read(authTokenProvider.notifier).state = token;
    return token != null;
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final token = await ref
          .read(authRepositoryProvider)
          .login(email, password);
      ref.read(authTokenProvider.notifier).state = token;
      await ref.read(syncEngineProvider.notifier).synchronize();
      return true;
    });
  }

  Future<void> register(String name, String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final token = await ref
          .read(authRepositoryProvider)
          .register(name, email, password);
      ref.read(authTokenProvider.notifier).state = token;
      return true;
    });
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    ref.read(authTokenProvider.notifier).state = null;
    state = const AsyncData(false);
  }
}

final sessionControllerProvider =
    AsyncNotifierProvider<SessionController, bool>(SessionController.new);
