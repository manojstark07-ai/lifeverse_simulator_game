/// Converts the engine's integer day counter into calendar dates.
///
/// Day 0 is the first day of the game: 1 June 2026, the month school results
/// are typically published. Using a plain integer keeps time monotonic and
/// makes negative time impossible to represent through the public API.
class GameCalendar {
  const GameCalendar._();

  static final DateTime start = DateTime.utc(2026, 6, 1);

  static DateTime dateOf(int day) => start.add(Duration(days: day));

  static int dayOf(DateTime date) => date.difference(start).inDays;

  /// A unique, ordered key for a calendar month (year * 12 + month index).
  static int monthKeyOfDay(int day) => monthKey(dateOf(day));

  static int monthKey(DateTime date) => date.year * 12 + (date.month - 1);

  static DateTime firstOfMonthKey(int key) =>
      DateTime.utc(key ~/ 12, key % 12 + 1, 1);

  /// Day index of the first day of the month after [day]'s month.
  static int startOfNextMonth(int day) {
    final d = dateOf(day);
    final next = DateTime.utc(d.year, d.month + 1, 1);
    return dayOf(next);
  }

  static int ageOn(DateTime birthDate, int day) {
    final d = dateOf(day);
    var age = d.year - birthDate.year;
    if (d.month < birthDate.month ||
        (d.month == birthDate.month && d.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  static const monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String formatDay(int day) {
    final d = dateOf(day);
    return '${d.day} ${monthNames[d.month - 1]} ${d.year}';
  }

  static String formatMonthKey(int key) =>
      '${monthNames[key % 12]} ${key ~/ 12}';
}
