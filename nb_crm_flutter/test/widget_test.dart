import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nb_crm_flutter/core/bloc/app_module_cubit.dart';
import 'package:nb_crm_flutter/core/theme/theme_cubit.dart';
import 'package:nb_crm_flutter/main.dart';

void main() {
  testWidgets('App boots under ProviderScope', (tester) async {
    final router = GoRouter(routes: []);
    final themeCubit = ThemeCubit();
    final appModuleCubit = AppModuleCubit();

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<ThemeCubit>.value(value: themeCubit),
          BlocProvider<AppModuleCubit>.value(value: appModuleCubit),
        ],
        child: ProviderScope(
          child: NbCrmApp(router: router),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(NbCrmApp), findsOneWidget);
  });
}
