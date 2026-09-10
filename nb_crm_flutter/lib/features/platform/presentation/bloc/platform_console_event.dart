import 'package:flutter/foundation.dart';

@immutable
sealed class PlatformConsoleEvent {
  const PlatformConsoleEvent();
}

class PlatformConsoleLoadRequested extends PlatformConsoleEvent {
  const PlatformConsoleLoadRequested();
}

class PlatformConsoleRefreshRequested extends PlatformConsoleEvent {
  const PlatformConsoleRefreshRequested();
}

class PlatformCompanyCreated extends PlatformConsoleEvent {
  const PlatformCompanyCreated({
    required this.name,
    required this.domain,
    this.plan = 'standard',
    this.status = 'ACTIVE',
    this.adminUsername,
    this.adminEmail,
    this.adminPassword,
  });

  final String name;
  final String domain;
  final String plan;
  final String status;
  final String? adminUsername;
  final String? adminEmail;
  final String? adminPassword;
}

class PlatformCompanyUpdated extends PlatformConsoleEvent {
  const PlatformCompanyUpdated({
    required this.id,
    this.name,
    this.domain,
    this.plan,
    this.status,
  });

  final String id;
  final String? name;
  final String? domain;
  final String? plan;
  final String? status;
}

class PlatformCompanyTrashed extends PlatformConsoleEvent {
  const PlatformCompanyTrashed(this.id, {this.superadminPassword});
  final String id;
  final String? superadminPassword;
}

class PlatformCompanyRestored extends PlatformConsoleEvent {
  const PlatformCompanyRestored(this.id);
  final String id;
}

class PlatformCompanyPurged extends PlatformConsoleEvent {
  const PlatformCompanyPurged(this.id, {this.superadminPassword});
  final String id;
  final String? superadminPassword;
}

class PlatformAdminPasswordReset extends PlatformConsoleEvent {
  const PlatformAdminPasswordReset({
    required this.adminId,
    required this.newPassword,
  });

  final String adminId;
  final String newPassword;
}

class PlatformAdminUnlocked extends PlatformConsoleEvent {
  const PlatformAdminUnlocked(this.adminId);
  final String adminId;
}

class PlatformAdminTrashed extends PlatformConsoleEvent {
  const PlatformAdminTrashed(this.id, {this.superadminPassword});
  final String id;
  final String? superadminPassword;
}

class PlatformAdminRestored extends PlatformConsoleEvent {
  const PlatformAdminRestored(this.id);
  final String id;
}

class PlatformAdminPurged extends PlatformConsoleEvent {
  const PlatformAdminPurged(this.id, {this.superadminPassword});
  final String id;
  final String? superadminPassword;
}

class PlatformTrashEmptied extends PlatformConsoleEvent {
  const PlatformTrashEmptied({this.superadminPassword});
  final String? superadminPassword;
}

class PlatformClearMessage extends PlatformConsoleEvent {
  const PlatformClearMessage();
}
