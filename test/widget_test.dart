import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_flip_runner/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const GravityFlipApp());
    expect(find.byType(GravityFlipApp), findsOneWidget);
  });
}
