// Basic Flutter smoke test for PeleIAApp.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peleia/main.dart';

void main() {
  testWidgets('PeleIAApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: PeleIAApp(),
      ),
    );
    expect(find.byType(PeleIAApp), findsOneWidget);
  });
}
