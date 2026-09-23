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
