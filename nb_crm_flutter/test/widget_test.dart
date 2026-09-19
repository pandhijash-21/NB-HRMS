import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_crm_flutter/core/bloc/app_module_cubit.dart';
import 'package:nb_crm_flutter/core/theme/theme_cubit.dart';

void main() {
  testWidgets('App boots under ProviderScope', (tester) async {
    final themeCubit = ThemeCubit();
    final appModuleCubit = AppModuleCubit();

    addTearDown(() async {
      await themeCubit.close();
      await appModuleCubit.close();
    });

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<ThemeCubit>.value(value: themeCubit),
          BlocProvider<AppModuleCubit>.value(value: appModuleCubit),
        ],
        child: const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(child: Text('NB CRM')),
            ),
          ),
        ),
      ),
    );

    expect(find.text('NB CRM'), findsOneWidget);
    expect(find.byType(ProviderScope), findsOneWidget);
  });
}
