import 'package:flutter_test/flutter_test.dart';
import 'package:phone_number_example/main.dart';

void main() {
  testWidgets('App loads with home title', (WidgetTester tester) async {
    await tester.pumpWidget(const App());

    expect(find.text('Functions'), findsOneWidget);
    expect(find.text('Auto-format'), findsOneWidget);
  });
}
