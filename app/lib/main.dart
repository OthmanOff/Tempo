import 'package:agenda_app/app/agenda_app.dart';
import 'package:agenda_app/core/notifications/notification_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  await container.read(notificationServiceProvider).initialize();
  runApp(
    UncontrolledProviderScope(container: container, child: const AgendaApp()),
  );
}
