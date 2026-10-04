import 'package:agenda_app/core/notifications/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calcule le déclenchement à partir du début et du délai', () {
    final startsAt = DateTime(2026, 10, 4, 14, 30);
    expect(
      reminderTrigger(startsAt, const Duration(minutes: 10)),
      DateTime(2026, 10, 4, 14, 20),
    );
  });

  test('produit un identifiant stable et distinct par délai', () {
    final first = notificationId('task-42', const Duration(minutes: 10));
    expect(first, notificationId('task-42', const Duration(minutes: 10)));
    expect(first, isNot(notificationId('task-42', const Duration(hours: 1))));
    expect(first, inInclusiveRange(0, 0x7fffffff));
  });
}
