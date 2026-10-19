import 'dart:ui' show Color;

/// Colores del mapa vectorial: los del tema claro de
/// `docs/mapa_vectorial/mapa-vectorial-referencia.html`. Cada nombre
/// indica entre paréntesis la variable CSS de la que sale.
abstract final class ColoresMapaVectorial {
  /// Fondo del widget (`--ground`).
  static const fondo = Color(0xFFEEF1EC);

  /// Terreno del campus (`--campus`) y su borde (`--line`).
  static const campus = Color(0xFFE2E8DF);
  static const bordeCampus = Color(0xFFCBD2C8);

  /// Áreas verdes (`--lawn`).
  static const areaVerde = Color(0xFFB3D99A);

  /// Zonas deportivas, canchas de fútbol y zonas techadas (`--pitch`) y
  /// las líneas de las canchas de fútbol (`--pitch-line`).
  static const cesped = Color(0xFF8EC57F);
  static const lineaCesped = Color(0xFFF4F8F2);

  /// Vialidades (`--street-edge`, `--street`, `--service`).
  static const bordeVialidad = Color(0xFFCDD3CB);
  static const calle = Color(0xFFFFFFFF);
  static const servicio = Color(0xFFF7F8F5);

  /// Edificios (`--building`, `--building-edge`, `--bldg-label`).
  static const edificio = Color(0xFF566676);
  static const bordeEdificio = Color(0xFF3E4B58);
  static const textoEdificio = Color(0xFFFFFFFF);

  /// Canchas (`--tennis-g`, `--tennis-b`, `--court-b`, `--court-r`,
  /// `--court-line`).
  static const tenisVerde = Color(0xFF22B14C);
  static const tenisAzul = Color(0xFF0015FF);
  static const baloncesto = Color(0xFF1C6FE0);
  static const marcaCancha = Color(0xFFE03131);
  static const lineaCancha = Color(0xFFFFFFFF);

  /// Insignias de íconos (`--badge`, `--badge-ink`).
  static const insignia = Color(0xFFFFFFFF);
  static const iconoInsignia = Color(0xFF2B5C9E);

  /// Entradas al campus (`--entry`, `--entry-ink`).
  static const entrada = Color(0xFF0E7C74);
  static const iconoEntrada = Color(0xFFFFFFFF);

  /// Textos oscuros (`--ink`), nombres de calles (`--muted`) y halo
  /// blanco (`--panel`).
  static const tinta = Color(0xFF1D2730);
  static const tenue = Color(0xFF5F6B74);
  static const halo = Color(0xFFFFFFFF);
}
