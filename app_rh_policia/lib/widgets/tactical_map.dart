import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';

/// Mapa táctico real (flutter_map) sobre Naucalpan, con unidades que se
/// mueven siguiendo calles reales, delitos y marcador propio.
class TacticalMap extends StatefulWidget {
  final bool showPatrols;
  final bool showCrimes;
  final bool showRoutes;
  final Officer? self;
  final void Function(CrimeReport)? onTapCrime;
  const TacticalMap({
    super.key,
    this.showPatrols = true,
    this.showCrimes = true,
    this.showRoutes = true,
    this.self,
    this.onTapCrime,
  });

  @override
  State<TacticalMap> createState() => _TacticalMapState();
}

class _TacticalMapState extends State<TacticalMap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final _map = MapController();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double get _t => DateTime.now().millisecondsSinceEpoch / 1000.0;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AnimatedBuilder(
        animation: Listenable.merge([_ctrl, AppStore.I]),
        builder: (context, _) {
          final store = AppStore.I;
          return Stack(
            children: [
              FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: widget.self?.position ?? store.center,
                  initialZoom: widget.self != null ? 15 : 13,
                  initialCameraFit: widget.self == null
                      ? CameraFit.bounds(
                          bounds: LatLngBounds(store.boundsSW, store.boundsNE),
                          padding: const EdgeInsets.all(24),
                        )
                      : null,
                  minZoom: 11,
                  maxZoom: 18,
                  backgroundColor: AppColors.mapBg,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                    subdomains: const ['a', 'b', 'c', 'd'],
                    retinaMode: RetinaMode.isHighDensity(context),
                    userAgentPackageName: 'com.demo.app_rh_policia',
                    tileProvider: NetworkTileProvider(),
                  ),
                  _cuadrantePolygons(store),
                  if (widget.showPatrols && widget.showRoutes)
                    _routeTrails(store),
                  _cuadranteLabels(store),
                  if (widget.showCrimes) _crimeWaves(store),
                  if (widget.showCrimes) _crimeMarkers(store),
                  if (widget.showPatrols) _patrolMarkers(store),
                  if (widget.self != null) _selfLayer(),
                  const _AttributionTag(),
                ],
              ),
              const Positioned.fill(child: IgnorePointer(child: _HudOverlay())),
            ],
          );
        },
      ),
    );
  }

  PolygonLayer _cuadrantePolygons(AppStore store) {
    return PolygonLayer(
      polygons: store.cuadrantes.map((cu) {
        return Polygon(
          points: cu.polygon,
          color: cu.color.withValues(alpha: 0.06),
          borderColor: cu.color.withValues(alpha: 0.5),
          borderStrokeWidth: 1.4,
        );
      }).toList(),
    );
  }

  /// Estela de la ruta restante de cada unidad: muestra que sigue calles.
  PolylineLayer _routeTrails(AppStore store) {
    return PolylineLayer(
      polylines: store.patrols
          .where((p) => p.route.length >= 2)
          .map((p) {
        final col = p.isOfficer ? AppColors.cyan : AppColors.teal;
        return Polyline(
          points: p.remaining,
          color: col.withValues(alpha: 0.35),
          strokeWidth: 2,
        );
      }).toList(),
    );
  }

  MarkerLayer _cuadranteLabels(AppStore store) {
    return MarkerLayer(
      markers: store.cuadrantes.map((cu) {
        return Marker(
          point: cu.centroid,
          width: 38,
          height: 20,
          child: GestureDetector(
            onTap: () => _showCuadrante(cu),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.mapBg.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: cu.color.withValues(alpha: 0.7)),
              ),
              child: Text(
                cu.corto,
                style: TextStyle(
                  color: cu.color,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showCuadrante(Cuadrante cu) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.panel,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 12, height: 12,
                    decoration: BoxDecoration(color: cu.color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(cu.nombre,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            if (cu.sector != null) _infoRow(Icons.layers, 'Sector', cu.sector!),
            if (cu.autoridad != null) _infoRow(Icons.account_balance, 'Autoridad', cu.autoridad!),
            if (cu.responsable != null) _infoRow(Icons.badge, 'Responsable', cu.responsable!),
            if (cu.telefono != null) _infoRow(Icons.phone, 'Teléfono', cu.telefono!),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: AppColors.textDim),
            const SizedBox(width: 10),
            Text('$k: ', style: const TextStyle(color: AppColors.textDim)),
            Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      );

  CircleLayer _crimeWaves(AppStore store) {
    final circles = <CircleMarker>[];
    for (final c in store.crimes) {
      final taken = c.tomadoPor != null;
      final base =
          taken ? AppColors.green : (c.reciente ? AppColors.red : AppColors.amber);
      for (int i = 0; i < 3; i++) {
        final phase = (_t * 0.6 + i / 3) % 1.0;
        circles.add(CircleMarker(
          point: c.position,
          radius: 8 + phase * 42,
          useRadiusInMeter: false,
          color: Colors.transparent,
          borderColor: base.withValues(alpha: (1 - phase) * (taken ? 0.2 : 0.55)),
          borderStrokeWidth: 2,
        ));
      }
    }
    return CircleLayer(circles: circles);
  }

  MarkerLayer _crimeMarkers(AppStore store) {
    return MarkerLayer(
      markers: store.crimes.map((c) {
        final taken = c.tomadoPor != null;
        final base = taken
            ? AppColors.green
            : (c.reciente ? AppColors.red : AppColors.amber);
        return Marker(
          point: c.position,
          width: 26,
          height: 26,
          child: GestureDetector(
            onTap: () => widget.onTapCrime?.call(c),
            child: Container(
              decoration: BoxDecoration(
                color: base,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(color: base.withValues(alpha: 0.6), blurRadius: 8)
                ],
              ),
              child: Icon(
                taken ? Icons.check : Icons.priority_high,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  MarkerLayer _patrolMarkers(AppStore store) {
    return MarkerLayer(
      markers: store.patrols.map((p) {
        final col = p.isOfficer ? AppColors.cyan : AppColors.teal;
        final pulse = 0.5 + 0.5 * sin(_t * 3 + p.position.longitude * 50);
        return Marker(
          point: p.position,
          width: 40,
          height: 40,
          rotate: true,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Halo de movimiento
              Container(
                width: 14 + pulse * 10,
                height: 14 + pulse * 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: col.withValues(alpha: 0.1),
                  border: Border.all(color: col.withValues(alpha: 0.2), width: 1),
                ),
              ),
              // Cuerpo de la unidad
              Transform.rotate(
                angle: p.isOfficer ? 0 : (p.heading - 90) * pi / 180,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: col,
                    borderRadius: BorderRadius.circular(p.isOfficer ? 8 : 3),
                    boxShadow: [
                      BoxShadow(color: col.withValues(alpha: 0.5), blurRadius: 4)
                    ],
                  ),
                  child: Icon(
                    p.isOfficer ? Icons.directions_walk : Icons.navigation,
                    size: 10,
                    color: Colors.black,
                  ),
                ),
              ),
              // Etiqueta pequeña
              Positioned(
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    p.label,
                    style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _selfLayer() {
    final pulse = (_t * 0.8) % 1.0;
    return MarkerLayer(
      markers: [
        Marker(
          point: widget.self!.position,
          width: 76,
          height: 76,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 20 + pulse * 52,
                height: 20 + pulse * 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.blue.withValues(alpha: (1 - pulse) * 0.7),
                    width: 2,
                  ),
                ),
              ),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.blue,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.navigation, size: 13, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AttributionTag extends StatelessWidget {
  const _AttributionTag();

  @override
  Widget build(BuildContext context) {
    return const RichAttributionWidget(
      animationConfig: ScaleRAWA(),
      attributions: [
        TextSourceAttribution('OpenStreetMap · CARTO · OSRM'),
      ],
    );
  }
}

class _HudOverlay extends StatelessWidget {
  const _HudOverlay();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          radius: 1.1,
          colors: [
            Colors.transparent,
            AppColors.mapBg.withValues(alpha: 0.35),
          ],
          stops: const [0.7, 1.0],
        ),
      ),
    );
  }
}
