import 'package:flutter_test/flutter_test.dart';
import 'package:complaint_system/main.dart';

void main() {
  testWidgets('Counter value smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp()); // Or whatever your base root widget class is named
  });
}