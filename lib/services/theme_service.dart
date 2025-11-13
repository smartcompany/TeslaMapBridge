import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemePreset { dark, light }

class ThemeService extends ChangeNotifier {
  static const _prefsKey = 'theme_preset';

  ThemePreset _preset = ThemePreset.dark;
  SharedPreferences? _prefs;

  ThemePreset get preset => _preset;

  ThemeData get themeData =>
      _preset == ThemePreset.dark ? _darkTheme : _lightTheme;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    final stored = _prefs?.getString(_prefsKey);
    if (stored != null) {
      _preset = ThemePreset.values.firstWhere(
        (preset) => preset.name == stored,
        orElse: () => ThemePreset.dark,
      );
    }
  }

  Future<void> setPreset(ThemePreset preset) async {
    if (_preset == preset) return;
    _preset = preset;
    notifyListeners();
    await _prefs?.setString(_prefsKey, preset.name);
  }
}

final ThemeData _darkTheme = ThemeData(
  brightness: Brightness.dark,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF6BA292),
    brightness: Brightness.dark,
    surface: const Color(0xFF1A1A1A),
    background: const Color(0xFF101418),
    onBackground: Colors.white,
  ),
  scaffoldBackgroundColor: const Color(0xFF101418),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF171C21),
    foregroundColor: Colors.white,
    elevation: 0,
  ),
  cardColor: const Color(0xFF1D2329),
  useMaterial3: true,
);

final ThemeData _lightTheme = ThemeData(
  brightness: Brightness.light,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF4B89A7),
    brightness: Brightness.light,
    surface: Colors.white,
    background: const Color(0xFFF5F6FA),
  ),
  scaffoldBackgroundColor: const Color(0xFFF5F6FA),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    foregroundColor: Colors.black,
    elevation: 0,
  ),
  cardColor: Colors.white,
  useMaterial3: true,
);
