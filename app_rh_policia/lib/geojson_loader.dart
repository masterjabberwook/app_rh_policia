import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import 'models.dart';
import 'theme.dart';

const _palette = [
  AppColors.cyan,
  AppColors.teal,
  AppColors.blue,
  AppColors.green,
  AppColors.amber,
  Color(0xFFA78BFA), // violeta
  Color(0xFFF472B6), // rosa
  Color(0xFF38BDF8), // celeste
];

/// Carga los cuadrantes reales (polígonos) del GeoJSON oficial de Naucalpan.
Future<List<Cuadrante>> loadCuadrantes() async {
  final raw = await rootBundle.loadString('assets/doc.geojson');
  final data = jsonDecode(raw) as Map<String, dynamic>;
  final features = data['features'] as List;

  final out = <Cuadrante>[];
  var idx = 0;
  for (final f in features) {
    final geom = f['geometry'];
    if (geom == null || geom['type'] != 'Polygon') continue;
    final props = (f['properties'] ?? {}) as Map<String, dynamic>;
    final name = (props['name'] ?? '').toString();
    if (!name.toLowerCase().contains('cuadrante')) continue;

    final ring = (geom['coordinates'] as List).first as List;
    final pts = ring
        .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();
    if (pts.length < 3) continue;

    double minLat = pts.first.latitude, maxLat = pts.first.latitude;
    double minLng = pts.first.longitude, maxLng = pts.first.longitude;
    double sumLat = 0, sumLng = 0;
    for (final p in pts) {
      minLat = p.latitude < minLat ? p.latitude : minLat;
      maxLat = p.latitude > maxLat ? p.latitude : maxLat;
      minLng = p.longitude < minLng ? p.longitude : minLng;
      maxLng = p.longitude > maxLng ? p.longitude : maxLng;
      sumLat += p.latitude;
      sumLng += p.longitude;
    }

    final numStr = RegExp(r'\d+').firstMatch(name)?.group(0) ?? '${idx + 1}';
    final id = numStr.padLeft(2, '0');

    out.add(Cuadrante(
      id: id,
      nombre: 'Cuadrante $id',
      corto: 'C$id',
      polygon: pts,
      centroid: LatLng(sumLat / pts.length, sumLng / pts.length),
      sw: LatLng(minLat, minLng),
      ne: LatLng(maxLat, maxLng),
      color: _palette[idx % _palette.length],
      sector: props['Sector']?.toString(),
      autoridad: props['Autoridad']?.toString(),
      responsable: props['Responsable']?.toString(),
      telefono: _cleanPhone(props['No. Telefonico']?.toString()),
    ));
    idx++;
  }

  out.sort((a, b) => a.id.compareTo(b.id));
  return out;
}

/// El GeoJSON trae teléfonos en notación científica (basura). Limpia o N/D.
String? _cleanPhone(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  if (raw.contains('E') || raw.contains('e')) return 'N/D';
  return raw;
}
