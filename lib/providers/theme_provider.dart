import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemeType {
  light,
  dark,
}

class ThemeProvider extends ChangeNotifier {
  ThemeType _themeType = ThemeType.light;

  ThemeType get themeType => _themeType;

  ThemeProvider() {
    _loadTheme();
  }

  void setTheme(ThemeType type) async {
    _themeType = type;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeType', type.toString());
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('themeType');
    
    if (savedTheme != null) {
      if (savedTheme.contains('amoled')) {
        _themeType = ThemeType.dark;
      } else {
        _themeType = ThemeType.values.firstWhere(
          (e) => e.toString() == savedTheme,
          orElse: () => ThemeType.light,
        );
      }
      notifyListeners();
    }
  }
}
