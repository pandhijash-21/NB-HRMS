import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../logging/app_logger.dart';

/// Global [BlocObserver] to log bloc transitions and errors in debug mode
/// with zero performance impact in release mode.
class AppBlocObserver extends BlocObserver {
  const AppBlocObserver();

  @override
  void onEvent(Bloc<dynamic, dynamic> bloc, Object? event) {
    super.onEvent(bloc, event);
    if (kDebugMode) {
      AppLogger.app.i('[Bloc Event] ${bloc.runtimeType}: $event');
    }
  }

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    if (kDebugMode) {
      // Optional fine-grained logging if needed
    }
  }

  @override
  void onTransition(
    Bloc<dynamic, dynamic> bloc,
    Transition<dynamic, dynamic> transition,
  ) {
    super.onTransition(bloc, transition);
    if (kDebugMode) {
      AppLogger.app.i(
        '[Bloc Transition] ${bloc.runtimeType} => ${transition.nextState.runtimeType}',
      );
    }
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    AppLogger.app.e(
      '[Bloc Error] ${bloc.runtimeType}: $error',
      error: error,
      stackTrace: stackTrace,
    );
    super.onError(bloc, error, stackTrace);
  }
}
