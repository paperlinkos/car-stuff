import 'package:flutter_test/flutter_test.dart';
import 'package:mota_mobile/main.dart';

void main() {
  testWidgets('welcome screen introduces the Mota prototype', (tester) async {
    await tester.pumpWidget(const MotaApp());
    expect(find.text('Explore the prototype'), findsOneWidget);
    expect(find.text('Move through Abuja\non your own terms.'), findsOneWidget);
  });

  testWidgets('role demo offers customer, owner and driver destinations', (tester) async {
    await tester.pumpWidget(const MotaApp());
    await tester.tap(find.text('Explore the prototype'));
    await tester.pumpAndSettle();
    expect(find.text('Customer'), findsWidgets);
    expect(find.text('Owner'), findsOneWidget);
    expect(find.text('Driver'), findsOneWidget);
  });
}
