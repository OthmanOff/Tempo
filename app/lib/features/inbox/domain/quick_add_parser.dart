class QuickAddResult {
  const QuickAddResult({
    required this.title,
    this.scheduledStartAt,
    this.estimatedDurationMinutes,
  });

  final String title;
  final DateTime? scheduledStartAt;
  final int? estimatedDurationMinutes;

  bool get hasSuggestions =>
      scheduledStartAt != null || estimatedDurationMinutes != null;
}

class QuickAddParser {
  static const _weekdays = {
    'lundi': DateTime.monday,
    'mardi': DateTime.tuesday,
    'mercredi': DateTime.wednesday,
    'jeudi': DateTime.thursday,
    'vendredi': DateTime.friday,
    'samedi': DateTime.saturday,
    'dimanche': DateTime.sunday,
  };

  QuickAddResult parse(String input, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final normalized = input.trim();
    if (normalized.isEmpty) return const QuickAddResult(title: '');

    var working = normalized;
    DateTime? day;
    final lower = working.toLowerCase();
    final dayExpression = RegExp(
      r"\b(aujourd['’]hui|demain|lundi|mardi|mercredi|jeudi|vendredi|samedi|dimanche)\b",
      caseSensitive: false,
    ).firstMatch(lower);
    if (dayExpression != null) {
      final token = dayExpression.group(0)!.toLowerCase().replaceAll('’', "'");
      final start = DateTime(reference.year, reference.month, reference.day);
      if (token == 'demain') {
        day = start.add(const Duration(days: 1));
      } else if (token == "aujourd'hui") {
        day = start;
      } else {
        final target = _weekdays[token]!;
        var delta = (target - start.weekday) % 7;
        if (delta == 0) delta = 7;
        day = start.add(Duration(days: delta));
      }
    }

    int? duration;
    Match? durationMatch;
    final minuteMatches = RegExp(
      r'\b(\d{1,3})\s*(min|minute|minutes)\b',
      caseSensitive: false,
    ).allMatches(working).toList();
    if (minuteMatches.isNotEmpty) {
      durationMatch = minuteMatches.last;
      duration = int.parse(durationMatch.group(1)!);
    }

    final hourMatches = RegExp(
      r'\b(\d{1,2})\s*(h|heure|heures)(?:\s*(\d{1,2})\s*(?:min|minutes?)?)?\b',
      caseSensitive: false,
    ).allMatches(working).toList();
    if (durationMatch == null && hourMatches.length >= 2) {
      durationMatch = hourMatches.last;
      duration =
          int.parse(durationMatch.group(1)!) * 60 +
          int.parse(durationMatch.group(3) ?? '0');
    } else if (durationMatch == null &&
        hourMatches.length == 1 &&
        day == null) {
      durationMatch = hourMatches.single;
      duration =
          int.parse(durationMatch.group(1)!) * 60 +
          int.parse(durationMatch.group(3) ?? '0');
    }

    int? hour;
    int minute = 0;
    Match? timeMatch;
    final clockMatches =
        RegExp(r'\b([01]?\d|2[0-3])(?::|h)([0-5]\d)?\b', caseSensitive: false)
            .allMatches(working)
            .where((match) => match.start != durationMatch?.start)
            .toList();
    if (day != null && clockMatches.isNotEmpty) {
      timeMatch = clockMatches.first;
      hour = int.parse(timeMatch.group(1)!);
      minute = int.parse(timeMatch.group(2) ?? '0');
    }

    final removals = <Match>[
      if (dayExpression != null) dayExpression,
      if (timeMatch != null) timeMatch,
      if (durationMatch != null) durationMatch,
    ]..sort((a, b) => b.start.compareTo(a.start));
    var titleSource = normalized;
    for (final match in removals) {
      titleSource = titleSource.replaceRange(match.start, match.end, ' ');
    }
    final title = titleSource
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceAll(RegExp(r'^[,;\-]+|[,;\-]+$'), '')
        .trim();
    final scheduled = day == null || hour == null
        ? null
        : DateTime(day.year, day.month, day.day, hour, minute);

    return QuickAddResult(
      title: title.isEmpty ? normalized : title,
      scheduledStartAt: scheduled,
      estimatedDurationMinutes: duration,
    );
  }
}
