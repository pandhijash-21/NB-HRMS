import 'dart:async';
import 'package:flutter/foundation.dart';

/// Bridges any Dart [Stream] (such as [Bloc.stream]) to a [Listenable]
/// for GoRouter's `refreshListenable`.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (_) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
