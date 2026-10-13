import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:janki_staff/core/models.dart';
import 'package:janki_staff/core/session.dart';
import 'package:janki_staff/core/theme.dart';
import 'package:janki_staff/screens/booking_form_screen.dart';
import 'package:janki_staff/screens/enquiry_screen.dart';
import 'package:janki_staff/screens/home_screen.dart';
import 'package:janki_staff/screens/login_screen.dart';
import 'package:janki_staff/screens/success_screen.dart';

/// Every screen must lay out without overflow on a small phone and on a
/// phone with large accessibility text.
void main() {
  final config = AppConfig.fromJson({
    'user': {'name': 'Reception Manager', 'username': 'manager', 'role': 'manager'},
    'site_name': 'Janki Agro Tourism',
    'today': '2026-10-13',
    'batches': [
      {
        'id': 4, 'name': 'Day Tour', 'booking_type': 'day_visit', 'start_time': '09:00:00', 'end_time': '14:00:00',
        'price_adult': 600, 'price_child': 450, 'is_active': true,
        'meal_plan': {'breakfast': 1, 'lunch': 1, 'snacks': 0, 'dinner': 0, 'high_tea': 0},
      },
      {
        'id': 6, 'name': 'Full Day with a rather long package name', 'booking_type': 'day_visit', 'start_time': '10:00:00',
        'end_time': '17:00:00', 'price_adult': 750, 'price_child': 600, 'is_active': true,
        'meal_plan': {'breakfast': 1, 'lunch': 1, 'snacks': 0, 'dinner': 0, 'high_tea': 1},
      },
      {
        'id': 7, 'name': 'Full Day Night AC Delux Room', 'booking_type': 'stay', 'start_time': '00:00:00', 'end_time': '00:00:00',
        'price_adult': 1800, 'price_child': 1300, 'is_active': true,
        'meal_plan': {'breakfast': 2, 'lunch': 1, 'snacks': 0, 'dinner': 1, 'high_tea': 1},
      },
    ],
    'meal_rates': {
      'breakfast': {'adult': 100, 'child': 60}, 'lunch': {'adult': 200, 'child': 120}, 'snacks': {'adult': 50, 'child': 30},
      'dinner': {'adult': 200, 'child': 120}, 'high_tea': {'adult': 40, 'child': 20},
    },
    'types': {'day_visit': true, 'stay': true},
    'holiday': {'days': [4], 'open': <String>[]},
  });

  Ticket ticket({required bool stay, bool paid = false, bool checkedIn = false}) => Ticket.fromJson({
        'id': 38, 'booking_id': 'ENQ-00038', 'name': 'Shubhangi Deshpande-Kulkarni', 'mobile': '9876543210', 'city': 'Pune',
        'visit_date': '2026-10-13', 'checkin_date': stay ? '2026-10-13' : null, 'checkout_date': stay ? '2026-10-15' : null,
        'nights': stay ? 2 : 1, 'batch_id': stay ? 7 : 4, 'batch_name': stay ? 'Full Day Night AC Delux Room' : 'Day Tour',
        'booking_type': stay ? 'stay' : 'day_visit', 'adult_count': 3, 'child_count': 2, 'status': 'confirmed', 'timing': '',
        'meals': '{}', 'price_adult': stay ? 1800 : 600, 'price_child': stay ? 1300 : 450, 'total_amount': 2700,
        'payment_type': paid ? '' : 'split', 'cash_amount': 1000, 'online_amount': 1700,
        'payment_status': paid ? 'paid' : 'unpaid', 'payment_gateway': paid ? 'razorpay' : '',
        'checkin_status': checkedIn ? 'checked_in' : 'not_checked_in', 'checkin_at': '13 Oct 2026, 01:46 PM', 'checkin_by': 'Manager',
        'ticket_url': 'https://example.com/booking/ticket.php?token=7cddb54de0662f3b70b706071e64fc73',
      });

  const result = BookingResult(
    title: 'Walk-in booked',
    bookingId: 'ENQ-00038',
    name: 'Shubhangi Deshpande-Kulkarni',
    mobile: '9876543210',
    ticketUrl: 'https://example.com/booking/ticket.php?token=7cddb54de0662f3b70b706071e64fc73',
    lines: [
      MapEntry('Guest', 'Shubhangi Deshpande-Kulkarni'),
      MapEntry('Package', 'Full Day with a rather long package name'),
      MapEntry('Payment', 'Split (cash + online)'),
    ],
  );

  final screens = <String, Widget Function()>{
    'login': () => const LoginScreen(),
    'home': () => const HomeScreen(),
    'walk-in form': () => const BookingFormScreen.walkin(),
    'check-in form (day, split payment)': () => BookingFormScreen.checkin(ticket: ticket(stay: false, checkedIn: true)),
    'check-in form (stay, paid online)': () => BookingFormScreen.checkin(ticket: ticket(stay: true, paid: true)),
    'enquiry form': () => const EnquiryScreen(),
    'success': () => SuccessScreen(result: result, againLabel: 'New walk-in booking', againIcon: Icons.add, againBuilder: (_) => const SizedBox()),
  };

  for (final size in const [Size(320, 568), Size(412, 915)]) {
    for (final scale in const [1.0, 1.6]) {
      for (final entry in screens.entries) {
        testWidgets('${entry.key} lays out at ${size.width.toInt()}×${size.height.toInt()}, text ×$scale', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          session.config = config;

          await tester.pumpWidget(
            MaterialApp(
              theme: buildTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: entry.value(),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);

          // Scroll through long forms so every section gets built
          final scrollable = find.byType(Scrollable);
          if (scrollable.evaluate().isNotEmpty) {
            await tester.drag(scrollable.first, const Offset(0, -3000));
            await tester.pump();
            expect(tester.takeException(), isNull);
          }
        });
      }
    }
  }

  testWidgets('walk-in form: validation, meal deduction and split payment', (tester) async {
    tester.view.physicalSize = const Size(412, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    session.config = config;
    await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: const BookingFormScreen.walkin()));

    // 1 adult × Rs. 600, both meals taken (the total shows in the bill and the bottom bar)
    expect(find.text('Rs. 600'), findsWidgets);

    // Add an adult and a child → 2×600 + 1×450
    await tester.tap(find.bySemanticsLabel('More Adults'));
    await tester.tap(find.bySemanticsLabel('More Children'));
    await tester.pump();
    expect(find.text('Rs. 1,650'), findsNWidgets(2));

    // Lunch switched off → − (2×200 + 1×120)
    await tester.tap(find.byType(Switch).at(1));
    await tester.pump();
    expect(find.text('Rs. 1,130'), findsNWidgets(2));
    expect(find.text('Lunch — not taken'), findsOneWidget);

    // Saving with nothing filled in shows what is missing instead of calling the website
    await tester.tap(find.text('Save booking'));
    await tester.pump();
    expect(find.text('Enter the customer\'s name'), findsWidgets);
    expect(find.text('Enter a valid 10-digit mobile number'), findsOneWidget);
    expect(find.text('Please select a payment type.'), findsOneWidget);

    // Split payment keeps cash + online equal to the total
    await tester.tap(find.text('Split'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Cash'), '500');
    await tester.pump();
    expect(find.widgetWithText(TextField, '630'), findsOneWidget);
    expect(find.text('Cash + Online = Rs. 1,130 ✓'), findsOneWidget);
  });
}
