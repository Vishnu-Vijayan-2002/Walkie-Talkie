import 'package:flutter_test/flutter_test.dart';
import 'package:connectx/main.dart';

void main() {
  testWidgets('ConnectX app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ConnectXApp());
    expect(find.text('Welcome to ConnectX'), findsOneWidget);
  });
}
