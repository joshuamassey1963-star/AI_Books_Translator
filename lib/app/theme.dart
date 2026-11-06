import 'package:flutter/material.dart';

/// Material 3 theme. Devanagari rendering relies on platform fonts in V1-A;
/// bundled Noto Sans Devanagari is planned for export (V1-E).
abstract final class AppTheme {
  static const Color _seed = Color(0xFF3F51B5);

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _seed),
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
        ),
      );
}
