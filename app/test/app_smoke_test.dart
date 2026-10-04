import 'package:agenda_app/app/agenda_app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('starts on the login screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: AgendaApp()));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Bon retour.'), findsOneWidget);
    expect(find.text('E-mail'), findsOneWidget);
    expect(find.text('Créer mon compte personnel'), findsOneWidget);
  });
}
