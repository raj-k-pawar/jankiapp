import 'package:flutter_test/flutter_test.dart';
import 'package:janki_staff/core/booking_calc.dart';
import 'package:janki_staff/core/format.dart';
import 'package:janki_staff/core/models.dart';

void main() {
  const rates = {
    'breakfast': MealRate(100, 60),
    'lunch': MealRate(200, 120),
    'snacks': MealRate(50, 30),
    'dinner': MealRate(200, 120),
    'high_tea': MealRate(40, 20),
  };
  const dayPlan = {'breakfast': 1, 'lunch': 1, 'snacks': 0, 'dinner': 0, 'high_tea': 0};

  group('BookingCalc', () {
    test('everyone takes every meal → no deduction', () {
      final meals = BookingCalc.defaultMeals(dayPlan, 2, 1);
      final p = BookingCalc.price(adults: 2, children: 1, priceAdult: 600, priceChild: 450, plan: dayPlan, meals: meals, rates: rates);
      expect(meals.keys, ['breakfast', 'lunch']);
      expect(p.base, 1650);
      expect(p.total, 1650);
    });

    test('meal switched off deducts it for every guest', () {
      final meals = BookingCalc.defaultMeals(dayPlan, 2, 1);
      meals['lunch']!.on = false;
      final p = BookingCalc.price(adults: 2, children: 1, priceAdult: 600, priceChild: 450, plan: dayPlan, meals: meals, rates: rates);
      expect(p.total, 1650 - (2 * 200 + 1 * 120));
    });

    test('partial quantity deducts only the servings not taken', () {
      final meals = BookingCalc.defaultMeals(dayPlan, 3, 2);
      meals['breakfast']!
        ..adultQty = 1
        ..childQty = 0;
      final p = BookingCalc.price(adults: 3, children: 2, priceAdult: 600, priceChild: 450, plan: dayPlan, meals: meals, rates: rates);
      expect(p.total, 2700 - (2 * 100 + 2 * 60));
    });

    test('stay is priced per night and never goes below zero', () {
      const stayPlan = {'breakfast': 2, 'lunch': 1, 'snacks': 0, 'dinner': 1, 'high_tea': 1};
      final meals = BookingCalc.defaultMeals(stayPlan, 2, 0);
      expect(meals['breakfast']!.adultQty, 4);
      final p = BookingCalc.price(adults: 2, children: 0, priceAdult: 1800, priceChild: 1300, plan: stayPlan, meals: meals, rates: rates, nights: 3);
      expect(p.total, 10800);

      for (final m in meals.values) {
        m.on = false;
      }
      final zero = BookingCalc.price(adults: 2, children: 0, priceAdult: 10, priceChild: 0, plan: stayPlan, meals: meals, rates: rates);
      expect(zero.total, 0);
    });

    test('saved booking keeps its adult/child split; older ones are seeded adults-first', () {
      Ticket ticket(Map<String, dynamic> extra) => Ticket.fromJson({
            'id': 7, 'adult_count': 2, 'child_count': 2, 'batch_id': 4, 'booking_type': 'day_visit', ...extra,
          });

      final split = BookingCalc.mealsFromTicket(
        ticket({'meals': '{"breakfast":true,"breakfast_adult_qty":1,"breakfast_child_qty":2,"lunch":false,"lunch_adult_qty":0,"lunch_child_qty":0}'}),
        dayPlan,
      );
      expect([split['breakfast']!.adultQty, split['breakfast']!.childQty, split['lunch']!.on], [1, 2, false]);

      final legacy = BookingCalc.mealsFromTicket(ticket({'meals': '{}', 'meal_breakfast_qty': 3, 'meal_lunch_qty': 0}), dayPlan);
      expect([legacy['breakfast']!.adultQty, legacy['breakfast']!.childQty], [2, 1]);
      expect([legacy['lunch']!.adultQty, legacy['lunch']!.childQty], [2, 2]);
    });
  });

  group('formatting', () {
    test('time, money and mobile', () {
      expect(fmtTime('15:00:00'), '03:00 PM');
      expect(fmtTime('00:30:00'), '12:30 AM');
      expect(rupees(165000), 'Rs. 1,65,000');
      expect(mobilePattern.hasMatch('9876543210'), isTrue);
      expect(mobilePattern.hasMatch('1234567890'), isFalse);
    });

    test('weekly holiday uses the website\'s weekday numbers (0 = Sunday)', () {
      final config = AppConfig.fromJson({
        'user': <String, dynamic>{}, 'today': '2026-10-13', 'batches': <dynamic>[],
        'holiday': {'days': [4], 'open': ['2026-10-22']},
      });
      expect(config.isHoliday(DateTime(2026, 10, 15)), isTrue); // Thursday
      expect(config.isHoliday(DateTime(2026, 10, 22)), isFalse); // Thursday, opened
      expect(config.isHoliday(DateTime(2026, 10, 16)), isFalse);
    });
  });
}
