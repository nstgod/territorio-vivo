import 'package:flutter/material.dart';

/// Design tokens do Território Vivo.
///
/// Toda tela usa estes valores (nunca números soltos) para manter
/// espaçamentos, raios e cores consistentes.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Largura máxima do conteúdo em telas grandes (tablet/web).
  static const double maxContentWidth = 840;
}

abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 14;
  static const double lg = 22;
  static const double pill = 999;

  static const BorderRadius card = BorderRadius.all(Radius.circular(md));
  static const BorderRadius chip = BorderRadius.all(Radius.circular(pill));
}

abstract final class AppDurations {
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 600);
}

/// Paleta da marca: verde-azulado "território" + âmbar de atenção.
abstract final class AppPalette {
  static const Color teal900 = Color(0xFF00382F);
  static const Color teal700 = Color(0xFF00695C);
  static const Color teal500 = Color(0xFF00897B);
  static const Color teal100 = Color(0xFFB2DFDB);
  static const Color sand50 = Color(0xFFF7F5EF);
  static const Color amber600 = Color(0xFFB26A00);
  static const Color amber300 = Color(0xFFFFC857);
  static const Color red700 = Color(0xFFB3261E);
  static const Color red300 = Color(0xFFFF8A80);
  static const Color green700 = Color(0xFF1B6E3A);
  static const Color green300 = Color(0xFF7DD69B);
  static const Color blue700 = Color(0xFF1F5FA8);
  static const Color blue300 = Color(0xFF9CC3FF);
  static const Color ink = Color(0xFF14201D);
}
