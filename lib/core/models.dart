import 'dart:convert';

import 'format.dart';

/// The 5 meal types the website tracks, in display order.
const List<String> mealTypes = ['breakfast', 'lunch', 'snacks', 'dinner', 'high_tea'];
const Map<String, String> mealLabels = {
  'breakfast': 'Breakfast',
  'lunch': 'Lunch',
  'snacks': 'Snacks',
  'dinner': 'Dinner',
  'high_tea': 'High Tea',
};
const Map<String, String> mealIcons = {
  'breakfast': '🍳',
  'lunch': '🍛',
  'snacks': '🍿',
  'dinner': '🍽️',
  'high_tea': '☕',
};

class StaffUser {
  const StaffUser({required this.name, required this.username, required this.role});

  final String name;
  final String username;
  final String role;

  factory StaffUser.fromJson(Map<String, dynamic> j) =>
      StaffUser(name: toStr(j['name']), username: toStr(j['username']), role: toStr(j['role']));
}

/// A package / time slot ("batch") as set up in the website's admin panel.
class Batch {
  const Batch({
    required this.id,
    required this.name,
    required this.bookingType,
    required this.startTime,
    required this.endTime,
    required this.priceAdult,
    required this.priceChild,
    required this.isActive,
    required this.mealPlan,
  });

  final int id;
  final String name;
  final String bookingType;
  final String startTime;
  final String endTime;
  final double priceAdult;
  final double priceChild;
  final bool isActive;

  /// Meal type → servings per guest included in this package.
  final Map<String, int> mealPlan;

  bool get isStay => bookingType == 'stay';

  /// "03:00 PM – 08:00 PM", or empty when the package has no time slot.
  String get timing {
    if (startTime.isEmpty || endTime.isEmpty || startTime == endTime) return '';
    return '${fmtTime(startTime)} – ${fmtTime(endTime)}';
  }

  factory Batch.fromJson(Map<String, dynamic> j) {
    final plan = <String, int>{};
    final raw = j['meal_plan'];
    if (raw is Map) {
      for (final meal in mealTypes) {
        plan[meal] = toInt(raw[meal]);
      }
    }
    return Batch(
      id: toInt(j['id']),
      name: toStr(j['name']),
      bookingType: toStr(j['booking_type']).isEmpty ? 'day_visit' : toStr(j['booking_type']),
      startTime: toStr(j['start_time']),
      endTime: toStr(j['end_time']),
      priceAdult: toDouble(j['price_adult']),
      priceChild: toDouble(j['price_child']),
      isActive: j['is_active'] == true,
      mealPlan: plan,
    );
  }
}

class MealRate {
  const MealRate(this.adult, this.child);

  final double adult;
  final double child;
}

/// Everything the forms need, loaded once after login (GET /config).
class AppConfig {
  const AppConfig({
    required this.user,
    required this.siteName,
    required this.today,
    required this.batches,
    required this.mealRates,
    required this.dayEnabled,
    required this.stayEnabled,
    required this.holidayWeekdays,
    required this.openDates,
  });

  final StaffUser user;
  final String siteName;

  /// The website's date (it decides what "today" means for tickets).
  final DateTime today;
  final List<Batch> batches;
  final Map<String, MealRate> mealRates;
  final bool dayEnabled;
  final bool stayEnabled;

  /// Weekly holidays, 0 = Sunday … 6 = Saturday.
  final Set<int> holidayWeekdays;

  /// Dates (yyyy-MM-dd) that fall on a weekly holiday but are open anyway.
  final Set<String> openDates;

  List<Batch> get activeDayBatches => batches.where((b) => b.isActive && !b.isStay).toList();

  Batch? batchById(int id) {
    for (final b in batches) {
      if (b.id == id) return b;
    }
    return null;
  }

  bool isHoliday(DateTime d) => holidayWeekdays.contains(d.weekday % 7) && !openDates.contains(ymd(d));

  factory AppConfig.fromJson(Map<String, dynamic> j) {
    final rates = <String, MealRate>{};
    final rawRates = j['meal_rates'];
    for (final meal in mealTypes) {
      final r = rawRates is Map ? rawRates[meal] : null;
      rates[meal] = r is Map ? MealRate(toDouble(r['adult']), toDouble(r['child'])) : const MealRate(0, 0);
    }
    final types = j['types'] is Map ? j['types'] as Map : const {};
    final holiday = j['holiday'] is Map ? j['holiday'] as Map : const {};
    final now = DateTime.now();
    return AppConfig(
      user: StaffUser.fromJson(j['user'] is Map<String, dynamic> ? j['user'] as Map<String, dynamic> : const {}),
      siteName: toStr(j['site_name']).isEmpty ? 'Janki Agro Tourism' : toStr(j['site_name']),
      today: parseYmd(toStr(j['today'])) ?? DateTime(now.year, now.month, now.day),
      batches: (j['batches'] is List ? j['batches'] as List : const [])
          .whereType<Map<String, dynamic>>()
          .map(Batch.fromJson)
          .toList(),
      mealRates: rates,
      dayEnabled: types['day_visit'] != false,
      stayEnabled: types['stay'] != false,
      holidayWeekdays: (holiday['days'] is List ? holiday['days'] as List : const []).map((e) => toInt(e, -1)).toSet(),
      openDates: (holiday['open'] is List ? holiday['open'] as List : const []).map(toStr).toSet(),
    );
  }
}

/// A booking as returned by the ticket lookup / check-in.
class Ticket {
  const Ticket({
    required this.id,
    required this.bookingId,
    required this.name,
    required this.mobile,
    required this.city,
    required this.visitDate,
    required this.checkinDate,
    required this.checkoutDate,
    required this.nights,
    required this.batchId,
    required this.batchName,
    required this.bookingType,
    required this.startTime,
    required this.endTime,
    required this.adults,
    required this.children,
    required this.status,
    required this.timing,
    required this.meals,
    required this.legacyMealQty,
    required this.priceAdult,
    required this.priceChild,
    required this.totalAmount,
    required this.paymentType,
    required this.cashAmount,
    required this.onlineAmount,
    required this.paymentStatus,
    required this.paymentGateway,
    required this.checkinStatus,
    required this.checkinAt,
    required this.checkinBy,
    required this.ticketUrl,
  });

  final int id;
  final String bookingId;
  final String name;
  final String mobile;
  final String city;
  final String visitDate;
  final String checkinDate;
  final String checkoutDate;
  final int nights;
  final int batchId;
  final String batchName;
  final String bookingType;
  final String startTime;
  final String endTime;
  final int adults;
  final int children;
  final String status;
  final String timing;

  /// The saved meal choices ({"lunch": true, "lunch_adult_qty": 2, …}).
  final Map<String, dynamic> meals;

  /// Combined per-meal quantity from bookings saved before adult/child splits existed.
  final Map<String, int> legacyMealQty;
  final double priceAdult;
  final double priceChild;
  final double totalAmount;
  final String paymentType;
  final double cashAmount;
  final double onlineAmount;
  final String paymentStatus;
  final String paymentGateway;
  final String checkinStatus;
  final String checkinAt;
  final String checkinBy;
  final String ticketUrl;

  bool get isStay => bookingType == 'stay';
  bool get isPaidOnline => paymentStatus == 'paid';
  bool get isCheckedIn => checkinStatus == 'checked_in';

  factory Ticket.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic> meals = const {};
    final rawMeals = j['meals'];
    if (rawMeals is Map<String, dynamic>) {
      meals = rawMeals;
    } else if (rawMeals is String && rawMeals.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawMeals);
        if (decoded is Map<String, dynamic>) meals = decoded;
      } on FormatException {
        // keep the empty default
      }
    }
    return Ticket(
      id: toInt(j['id']),
      bookingId: toStr(j['booking_id']),
      name: toStr(j['name']),
      mobile: toStr(j['mobile']),
      city: toStr(j['city']),
      visitDate: toStr(j['visit_date']),
      checkinDate: toStr(j['checkin_date']),
      checkoutDate: toStr(j['checkout_date']),
      nights: toInt(j['nights'], 1) < 1 ? 1 : toInt(j['nights'], 1),
      batchId: toInt(j['batch_id']),
      batchName: toStr(j['batch_name']),
      bookingType: toStr(j['booking_type']).isEmpty ? 'day_visit' : toStr(j['booking_type']),
      startTime: toStr(j['start_time']),
      endTime: toStr(j['end_time']),
      adults: toInt(j['adult_count'], 1),
      children: toInt(j['child_count']),
      status: toStr(j['status']),
      timing: toStr(j['timing']),
      meals: meals,
      legacyMealQty: {for (final meal in mealTypes) meal: toInt(j['meal_${meal}_qty'])},
      priceAdult: toDouble(j['price_adult']),
      priceChild: toDouble(j['price_child']),
      totalAmount: toDouble(j['total_amount']),
      paymentType: toStr(j['payment_type']),
      cashAmount: toDouble(j['cash_amount']),
      onlineAmount: toDouble(j['online_amount']),
      paymentStatus: toStr(j['payment_status']),
      paymentGateway: toStr(j['payment_gateway']),
      checkinStatus: toStr(j['checkin_status']),
      checkinAt: toStr(j['checkin_at']),
      checkinBy: toStr(j['checkin_by']),
      ticketUrl: toStr(j['ticket_url']),
    );
  }
}

/// What the success screen shows after a booking is saved.
class BookingResult {
  const BookingResult({
    required this.title,
    required this.bookingId,
    required this.name,
    required this.mobile,
    required this.ticketUrl,
    required this.lines,
  });

  final String title;
  final String bookingId;
  final String name;
  final String mobile;
  final String ticketUrl;

  /// Label → value rows of the summary.
  final List<MapEntry<String, String>> lines;
}
