import 'package:flutter/material.dart';

/// Paleta institucional / gobierno.
class AppColors {
  // Marca Morena · Naucalpan (Modo Oscuro Premium).
  static const bg = Color(0xFF0F0B0C); // fondo general (blanco piedra / mármol suave)
  static const panel = Color(0xFF160F12); // superficies / tarjetas / appbar
  static const panelHi = Color(0xFF1E1418); // superficie arena suave institucional
  static const grid = Color(0xFF2B1F23); // bordes color piedra/arena
  static const text = Color(0xFFF2ECEE); // tinta principal
  static const textDim = Color(0xFFAB9CA2); // texto secundario sobrio

  static const guinda = Color(0xFFC22D60); // primario Morena/vino oficial
  static const guindaDark = Color(0xFF611232); // guinda profundo oficial
  static const oro = Color(0xFFD4AF37); // dorado institucional

  // Estados accesibles sobre blanco/oscuro.
  static const success = Color(0xFF34D399); // verde olivo institucional
  static const danger = Color(0xFFF87171); // rojo lacre oficial
  static const warn = Color(0xFFFBBF24); // ocre de advertencia
  static const info = Color(0xFF60A5FA);

  // Mapa (se mantiene oscuro, no cambia).
  static const mapBg = Color(0xFF0B1220);

  // Marcadores del mapa neón (NO cambian).
  static const cyan = Color(0xFF22D3EE);
  static const teal = Color(0xFF2DD4BF);
  static const blue = Color(0xFF3B82F6);
  static const green = Color(0xFF34D399);
  static const amber = Color(0xFFFBBF24);
  static const red = Color(0xFFEF4444);
  static const whatsapp = Color(0xFF25D366);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.guinda,
    brightness: Brightness.dark,
  ).copyWith(
    surface: AppColors.panel,
    primary: AppColors.guinda,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    fontFamily: 'Roboto',
    textTheme: const TextTheme().apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.panel,
      foregroundColor: AppColors.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      shape: Border(bottom: BorderSide(color: AppColors.oro, width: 2)), // Línea dorada inferior
    ),
    cardTheme: const CardThemeData(
      color: AppColors.panel,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: AppColors.grid, width: 1.2),
        borderRadius: BorderRadius.all(Radius.circular(6)), // Radio reducido más militar/formal
      ),
    ),
    dividerColor: AppColors.grid,
  );
}

/// Tarjeta institucional plana. [glow] (opcional) pinta una barra de acento
/// a la izquierda para destacar la categoría.
class HudPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? glow;
  const HudPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.glow,
  });

  @override
  Widget build(BuildContext context) {
    final accent = glow;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(6), // Radio de borde de 6px más formal y geométrico
        border: Border.all(color: AppColors.grid, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04), // Sombra extremadamente tenue y fina
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: accent == null
          ? Padding(padding: padding, child: child)
          : IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 4, color: accent), // franja de acento
                  Expanded(child: Padding(padding: padding, child: child)),
                ],
              ),
            ),
    );
  }
}
