import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mota_mobile/customer/customer_home_screen.dart';
import 'package:mota_mobile/main.dart';

void main() {
  testWidgets('prototype opens directly into the customer experience',
      (tester) async {
    await tester.pumpWidget(const MotaApp());
    expect(find.text('Good afternoon.'), findsOneWidget);
    expect(find.text('LOCAL PROTOTYPE · NO ACCOUNT REQUIRED'), findsOneWidget);
    expect(find.text('Rent a Car\nYour Way'), findsOneWidget);
    expect(find.text('Popular Cars'), findsOneWidget);
  });

  testWidgets('role demo offers customer, owner and driver destinations',
      (tester) async {
    await tester.pumpWidget(const MotaApp());
    expect(find.text('Customer'), findsWidgets);
    expect(find.text('Owner'), findsOneWidget);
    expect(find.text('Driver'), findsOneWidget);

    await tester.tap(find.text('Owner'));
    await tester.pumpAndSettle();
    expect(find.text('OWNER WORKSPACE'), findsOneWidget);

    await tester.tap(find.text('Driver'));
    await tester.pumpAndSettle();
    expect(find.text('DRIVER WORKSPACE'), findsOneWidget);

    await tester.tap(find.text('Customer'));
    await tester.pumpAndSettle();
    expect(find.text('Popular Cars'), findsOneWidget);
  });

  testWidgets('category filtering and card selection open luxury detail',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MotaApp());
    await tester.pumpAndSettle();

    // Verify category chips are present
    expect(find.text('All'), findsOneWidget);
    expect(find.text('SUV'), findsOneWidget);
    expect(find.text('Electric'), findsWidgets);

    // Tap Electric category chip
    await tester.tap(find.text('Electric').first);
    await tester.pumpAndSettle();

    // Verify Tesla is displayed
    final teslaFinder = find.text('Tesla Model Y');
    expect(teslaFinder, findsWidgets);

    // Tap Tesla card to open luxury detail view
    await tester.tap(teslaFinder.first);
    await tester.pumpAndSettle();

    expect(find.byType(LuxuryVehicleDetailScreen), findsOneWidget);
    expect(find.text('Specifications'), findsOneWidget);
    expect(find.text('Reserve This Vehicle'), findsOneWidget);
  });
}
