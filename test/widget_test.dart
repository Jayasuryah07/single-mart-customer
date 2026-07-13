import 'package:flutter_test/flutter_test.dart';
import 'package:singlemart/main.dart';

void main() {
  testWidgets('Splash screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SingleMartApp());

    // Verify that the splash screen shows the app name.
    expect(find.text('SingleMart'), findsOneWidget);
  });
}
