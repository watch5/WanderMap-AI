import 'package:flutter_test/flutter_test.dart';

import 'package:wander_map_ai/main.dart';

void main() {
  testWidgets('WanderMap AI アプリが起動する', (WidgetTester tester) async {
    await tester.pumpWidget(const WanderMapApp());
    expect(find.text('WanderMap AI'), findsOneWidget);
  });
}
