import 'package:agenda_app/features/inbox/domain/quick_add_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final parser = QuickAddParser();
  final now = DateTime(2026, 10, 3, 12);

  test('keeps plain text as an inbox title', () {
    final result = parser.parse('Appeler assurance', now: now);
    expect(result.title, 'Appeler assurance');
    expect(result.hasSuggestions, isFalse);
  });

  test('parses tomorrow, time and duration', () {
    final result = parser.parse('Réviser IA demain 18h 1h', now: now);
    expect(result.title, 'Réviser IA');
    expect(result.scheduledStartAt, DateTime(2026, 10, 4, 18));
    expect(result.estimatedDurationMinutes, 60);
  });

  test('parses the next named weekday and minute duration', () {
    final result = parser.parse('Rapport lundi 09:30 45 min', now: now);
    expect(result.title, 'Rapport');
    expect(result.scheduledStartAt, DateTime(2026, 10, 5, 9, 30));
    expect(result.estimatedDurationMinutes, 45);
  });

  test('falls back to the raw value when parsing cannot extract a title', () {
    final result = parser.parse('demain', now: now);
    expect(result.title, 'demain');
  });
}
