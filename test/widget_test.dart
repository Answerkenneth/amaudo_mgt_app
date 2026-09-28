import 'package:flutter_test/flutter_test.dart';
import 'package:amaudo_management_app/main.dart';

void main() {
  testWidgets('App builds without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const AmaudoApp());
    expect(find.byType(AmaudoApp), findsOneWidget);
  });
}