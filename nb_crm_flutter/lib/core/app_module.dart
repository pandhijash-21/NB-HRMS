import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppModule { hrms, crm, erp }

const _kAppModuleKey = 'app_shell_module';

String shellBrandTitle(AppModule module) {
  return switch (module) {
    AppModule.hrms => 'NB HRMS',
    AppModule.crm => 'NB CRM',
    AppModule.erp => 'NB ERP',
  };
}

bool isSharedShellPath(String path) {
  return path.startsWith('/org-tree') ||
      path.startsWith('/chat') ||
      path.startsWith('/meet') ||
      path.startsWith('/tasks');
}

AppModule inferAppModule(String path, AppModule current) {
  if (path.startsWith('/erp')) return AppModule.erp;
  if (path.startsWith('/crm')) return AppModule.crm;
  if (isSharedShellPath(path)) return current;
  return AppModule.hrms;
}

final appModuleProvider = NotifierProvider<AppModuleNotifier, AppModule>(AppModuleNotifier.new);

class AppModuleNotifier extends Notifier<AppModule> {
  @override
  AppModule build() {
    Future.microtask(_load);
    return AppModule.hrms;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kAppModuleKey);
      final loaded = switch (raw) {
        'crm' => AppModule.crm,
        'erp' => AppModule.erp,
        'hrms' => AppModule.hrms,
        _ => null,
      };
      if (loaded != null && ref.mounted) state = loaded;
    } catch (_) {}
  }

  Future<void> _persist(AppModule module) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kAppModuleKey,
        switch (module) {
          AppModule.hrms => 'hrms',
          AppModule.crm => 'crm',
          AppModule.erp => 'erp',
        },
      );
    } catch (_) {}
  }

  void setModule(AppModule module) {
    if (state == module) return;
    state = module;
    _persist(module);
  }

  AppModule syncFromPath(String path) {
    final next = inferAppModule(path, state);
    if (next != state) {
      state = next;
      _persist(next);
    }
    return next;
  }
}
