import 'dart:async';

import 'package:agenda_app/core/database/app_database.dart';
import 'package:agenda_app/core/sync/sync_engine.dart';
import 'package:agenda_app/features/auth/data/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final sessionUserProvider = StateProvider<LocalUser?>((ref) => null);

final activeUserProvider = StreamProvider<LocalUser?>((ref) {
  final sessionUser = ref.watch(sessionUserProvider);
  if (sessionUser != null) return Stream.value(sessionUser);
  final database = ref.watch(appDatabaseProvider);
  return (database.select(database.users)..limit(1)).watchSingleOrNull();
});

class SessionController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    // The offline database is required by every authenticated screen. Opening
    // it here makes web setup failures visible immediately instead of letting
    // authentication succeed before all task, project and event writes fail.
    await ref.read(appDatabaseProvider).customSelect('SELECT 1').get();
    final session = await ref.read(authRepositoryProvider).restoreSession();
    ref.read(authTokenProvider.notifier).state = session?.token;
    ref.read(sessionUserProvider.notifier).state = session?.user;
    return session != null;
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final session = await ref
          .read(authRepositoryProvider)
          .login(email, password);
      ref.read(authTokenProvider.notifier).state = session.token;
      ref.read(sessionUserProvider.notifier).state = session.user;
      unawaited(_synchronizeInBackground());
      return true;
    });
  }

  Future<void> _synchronizeInBackground() async {
    try {
      await ref.read(syncEngineProvider.notifier).synchronize();
    } catch (_) {
      // Authentication succeeded. The sync engine keeps its own failure state
      // and can be retried without sending the user back to the login screen.
    }
  }

  Future<void> register(String name, String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final session = await ref
          .read(authRepositoryProvider)
          .register(name, email, password);
      ref.read(authTokenProvider.notifier).state = session.token;
      ref.read(sessionUserProvider.notifier).state = session.user;
      return true;
    });
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    ref.read(authTokenProvider.notifier).state = null;
    ref.read(sessionUserProvider.notifier).state = null;
    state = const AsyncData(false);
  }
}

final sessionControllerProvider =
    AsyncNotifierProvider<SessionController, bool>(SessionController.new);
