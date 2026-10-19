/// True when API `sts` represents a subscription (legacy or granular weekly/monthly).
bool isSubscriptionSts(String? sts) {
  if (sts == null) return false;
  final s = sts.toString().trim().toLowerCase();
  return s.contains('subscription') ||
      s.contains('weekly') ||
      s.contains('15day') ||
      s.contains('monthly') ||
      s.contains('7day') ||
      s.contains('7 days');
}

/// Vendor drive-in / scheduled / hourly-pass bookings (excludes subscription `sts` values).
bool isVendorShortParkingSts(String? sts) {
  if (sts == null) return false;
  final s = sts.toString().trim();
  if (s == 'Instant' || s == 'Schedule') return true;
  // Match 12hr, 12h, 24hr, 24h etc.
  return RegExp(r'^\d+(?:hr|h)$', caseSensitive: false).hasMatch(s);
}

/// True when `sts` is a weekly (7-day) or 15-day pass — these do not support renewal.
bool isWeeklyOr15DayPassSts(String? sts) {
  if (sts == null) return false;
  final s = sts.toLowerCase();
  return s.contains('weekly') || s.contains('7day') || s.contains('7 days') || s.contains('15day');
}

/// `sts` like 12hr / 24hr — fixed pass: fee stays [booking.amount] for exit, not duration-based upgrades.
bool isFixedHourPassSts(String? sts) {
  if (sts == null) return false;
  return RegExp(r'^\d+(?:hr|h)$', caseSensitive: false).hasMatch(sts.toString().trim());
}

/// Fixed hour-pass (12, 24, 48, 72 hours / Full Day)
bool isPassSts(String? sts, [String? bookType]) {
  if (bookType != null) {
    final bt = bookType.trim().toLowerCase();
    if (bt == '24 hours' || bt == '24hours') return true;
  }
  if (sts == null) return false;
  final s = sts.toString().trim().toLowerCase();
  if (s == 'fullday' ||
      s == 'full day' ||
      s == '24 hours' ||
      s == '24hours') {
    return true;
  }
  final m = RegExp(r'^(\d+)(?:hr|h)?$', caseSensitive: false).firstMatch(s);
  if (m != null) {
    final hours = int.tryParse(m.group(1) ?? '') ?? 0;
    if (hours == 12 || hours == 24 || hours == 48 || hours == 72) {
      return true;
    }
  }
  return false;
}

/// True when booking represents a fixed pass or subscription (paid upfront upon booking)
bool isPassOrSubscriptionSts(String? sts, [String? bookType]) {
  return isSubscriptionSts(sts) || isPassSts(sts, bookType);
}
