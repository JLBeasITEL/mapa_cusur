import 'package:flutter/material.dart';

/// Poppins empaquetada localmente (ver `fonts:` en `pubspec.yaml`), en vez
/// de `google_fonts`: ese paquete descargaba las tipografías de internet
/// la primera vez que la app las necesitaba, lo que contradecía la
/// afirmación -en la tesis y en el README- de que la app es 100% offline.
///
/// Mismo uso que `GoogleFonts.poppins(...)`, sin red: los 4 pesos
/// declarados en el pubspec (400/500/600/700) son los únicos que usa la
/// app.
TextStyle poppins({
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
  double? letterSpacing,
}) {
  return TextStyle(
    fontFamily: 'Poppins',
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
  );
}

/// Equivalente local de `GoogleFonts.poppinsTextTheme()`: aplica la
/// familia tipográfica Poppins a todo el `TextTheme` que reciba.
TextTheme poppinsTextTheme(TextTheme base) => base.apply(fontFamily: 'Poppins');
