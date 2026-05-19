import 'package:flutter_test/flutter_test.dart';
import 'package:bichofue/main.dart';

void main() {
  testWidgets('App starts with splash screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const BichofueApp());

    // Verify that the splash screen shows the app name.
    expect(find.text('Bichofué'), findsOneWidget);
    expect(find.text('Descubre Cali a tu manera'), findsOneWidget);
  });
}
