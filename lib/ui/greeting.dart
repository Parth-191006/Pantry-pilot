/// Time-aware greeting used on the home hero. Pure function — deterministic
/// and easy to test.
String timeGreeting(DateTime now) {
  final h = now.hour;
  if (h < 5) return 'Late-night cravings?';
  if (h < 12) return 'Good morning, chef 👋';
  if (h < 17) return 'Good afternoon, chef 👋';
  if (h < 22) return 'Good evening, chef 👋';
  return 'Late-night cravings?';
}

/// Compact duration label for recipe cards: "20 min", "1 h 5 min".
String formatMinutes(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h h' : '$h h $m min';
}
