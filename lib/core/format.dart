import 'package:intl/intl.dart';

final DateFormat _ymd = DateFormat('yyyy-MM-dd');
final DateFormat _pretty = DateFormat('d MMM yyyy');
final DateFormat _prettyDay = DateFormat('EEE, d MMM yyyy');
final NumberFormat _inr = NumberFormat.decimalPattern('en_IN');

/// 2026-10-13 — the format the website expects.
String ymd(DateTime d) => _ymd.format(d);

DateTime? parseYmd(String? s) {
  if (s == null || s.length < 10) return null;
  return DateTime.tryParse(s.substring(0, 10));
}

String prettyDate(DateTime d) => _pretty.format(d);
String prettyDateWithDay(DateTime d) => _prettyDay.format(d);

/// Rs. 1,650
String rupees(num n) => 'Rs. ${_inr.format(n.round())}';

/// "15:00:00" → "03:00 PM" (same as the website's fmtTime).
String fmtTime(String t) {
  final parts = t.split(':');
  if (parts.length < 2) return t;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return t;
  final suffix = h >= 12 ? 'PM' : 'AM';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '${h12.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $suffix';
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

int toInt(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.toInt() ?? fallback;
  return fallback;
}

double toDouble(dynamic v, [double fallback = 0]) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

String toStr(dynamic v) => v == null ? '' : v.toString();

final RegExp mobilePattern = RegExp(r'^[6-9][0-9]{9}$');
