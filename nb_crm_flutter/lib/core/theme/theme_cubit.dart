import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kThemeModeKey = 'app_theme_mode';

class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kThemeModeKey);
      if (raw == null) return;
      final mode = switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => null,
      };
      if (mode != null && !isClosed) {
        emit(mode);
      }
    } catch (_) {}
  }

  Future<void> _persist(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
      await prefs.setString(_kThemeModeKey, value);
    } catch (_) {}
  }

  void toggleTheme() {
    if (state == ThemeMode.light || state == ThemeMode.system) {
      setTheme(ThemeMode.dark);
    } else {
      setTheme(ThemeMode.light);
    }
  }

  void setTheme(ThemeMode mode) {
    if (state == mode) return;
    emit(mode);
    _persist(mode);
  }
}
