import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nb_crm_flutter/main.dart';

void main() {
  testWidgets('App boots under ProviderScope', (tester) async {
    final router = GoRouter(routes: []);
    await tester.pumpWidget(ProviderScope(child: NbCrmApp(router: router)));
    await tester.pump();
    expect(find.byType(NbCrmApp), findsOneWidget);
  });
}
