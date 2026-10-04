({DateTime start, DateTime end}) localDayRange(DateTime date) {
  final start = DateTime(date.year, date.month, date.day);
  return (start: start, end: start.add(const Duration(days: 1)));
}
