import 'in_app_update_service.dart';

/// Web / non-Android stub — in-app updates are not available.

Future<bool> checkUpdateAvailable() async => false;

Future<InAppUpdateResult> startImmediateUpdate() async =>
    InAppUpdateResult.unsupported;

Future<InAppUpdateResult> startFlexibleUpdate() async =>
    InAppUpdateResult.unsupported;

Future<void> completeUpdate() async {}
