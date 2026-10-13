import 'dart:math' as math;

import 'models.dart';

/// One meal's choice in the booking form.
class MealChoice {
  MealChoice({required this.on, required this.adultQty, required this.childQty});

  bool on;
  int adultQty;
  int childQty;
}

class MealLine {
  const MealLine({required this.meal, required this.full, required this.taken, required this.on, required this.deduction});

  final String meal;
  final int full;
  final int taken;
  final bool on;
  final double deduction;
}

class PriceBreakdown {
  const PriceBreakdown({required this.base, required this.mealLines, required this.total});

  final double base;
  final List<MealLine> mealLines;
  final double total;

  double get deductions => mealLines.fold(0, (sum, l) => sum + l.deduction);
}

/// Pricing and meal rules of the website's check-in / walk-in popup, kept in
/// one place so the app always shows the same numbers as the website.
class BookingCalc {
  /// Meals this package includes (servings per guest > 0), in display order.
  static List<String> mealsInPlan(Map<String, int> plan) => mealTypes.where((m) => (plan[m] ?? 0) > 0).toList();

  /// Every included meal switched on for every guest (new booking, or after
  /// the package changes).
  static Map<String, MealChoice> defaultMeals(Map<String, int> plan, int adults, int children) {
    return {
      for (final meal in mealsInPlan(plan))
        meal: MealChoice(on: true, adultQty: adults * plan[meal]!, childQty: children * plan[meal]!),
    };
  }

  /// Meal choices of a saved booking.
  static Map<String, MealChoice> mealsFromTicket(Ticket t, Map<String, int> plan) {
    final result = <String, MealChoice>{};
    for (final meal in mealsInPlan(plan)) {
      final mult = plan[meal]!;
      final fullAdult = t.adults * mult;
      final fullChild = t.children * mult;
      final on = t.meals[meal] != false;
      final savedA = t.meals['${meal}_adult_qty'];
      final savedC = t.meals['${meal}_child_qty'];
      int adultQty;
      int childQty;
      if (savedA is num && savedC is num) {
        adultQty = savedA.toInt();
        childQty = savedC.toInt();
      } else {
        // No adult/child split saved yet — seed adults-first from the old combined quantity
        final legacy = t.legacyMealQty[meal] ?? 0;
        final combined = (on && legacy <= 0) ? fullAdult + fullChild : legacy;
        adultQty = math.min(combined, fullAdult);
        childQty = math.max(0, combined - adultQty);
      }
      result[meal] = MealChoice(
        on: on,
        adultQty: adultQty.clamp(0, fullAdult),
        childQty: childQty.clamp(0, fullChild),
      );
    }
    return result;
  }

  /// Guests × rate (× nights for a stay), minus a deduction for every meal
  /// serving the guests are not taking.
  static PriceBreakdown price({
    required int adults,
    required int children,
    required double priceAdult,
    required double priceChild,
    required Map<String, int> plan,
    required Map<String, MealChoice> meals,
    required Map<String, MealRate> rates,
    int nights = 1,
  }) {
    final base = (adults * priceAdult + children * priceChild) * math.max(1, nights);
    final lines = <MealLine>[];
    var deduct = 0.0;
    for (final meal in mealsInPlan(plan)) {
      final choice = meals[meal];
      if (choice == null) continue;
      final mult = plan[meal]!;
      final fullAdult = adults * mult;
      final fullChild = children * mult;
      final rate = rates[meal] ?? const MealRate(0, 0);
      final takenAdult = choice.on ? choice.adultQty.clamp(0, fullAdult) : 0;
      final takenChild = choice.on ? choice.childQty.clamp(0, fullChild) : 0;
      final d = (fullAdult - takenAdult) * rate.adult + (fullChild - takenChild) * rate.child;
      deduct += d;
      lines.add(MealLine(meal: meal, full: fullAdult + fullChild, taken: takenAdult + takenChild, on: choice.on, deduction: d));
    }
    return PriceBreakdown(base: base, mealLines: lines, total: math.max(0, base - deduct));
  }
}
