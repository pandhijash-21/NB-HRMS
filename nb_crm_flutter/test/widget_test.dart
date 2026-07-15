import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nb_crm_flutter/main.dart';

void main() {
  testWidgets('App boots under ProviderScope', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: NbCrmApp()));
    await tester.pump();
    expect(find.byType(NbCrmApp), findsOneWidget);
  });
}
