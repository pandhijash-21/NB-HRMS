import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_module.dart';

export '../app_module.dart'
    show AppModule, shellBrandTitle, isSharedShellPath, inferAppModule;

const _kAppModuleKey = 'app_shell_module';

class AppModuleCubit extends Cubit<AppModule> {
  AppModuleCubit() : super(AppModule.hrms) {
    _load();
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
      if (loaded != null && !isClosed) {
        emit(loaded);
      }
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
    emit(module);
    _persist(module);
  }

  AppModule syncFromPath(String path) {
    final next = inferAppModule(path, state);
    if (next != state) {
      emit(next);
      _persist(next);
    }
    return next;
  }
}

