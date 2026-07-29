import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Cliente de ruteo vial usando el servidor público OSRM.
/// Devuelve la geometría (lista de vértices) que sigue las calles reales.
class RoadRouter {
  static const _base = 'https://router.project-osrm.org/route/v1/driving/';
  final _client = http.Client();

  // Limita peticiones concurrentes para no saturar el servidor demo.
  int _active = 0;
  static const maxConcurrent = 4;
  bool get busy => _active >= maxConcurrent;

  Future<List<LatLng>?> route(LatLng a, LatLng b) async {
    if (busy) return null;
    _active++;
    try {
      final url = '$_base${a.longitude},${a.latitude};'
          '${b.longitude},${b.latitude}'
          '?overview=full&geometries=geojson';
      final res = await _client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;
      final coords = (routes[0]['geometry']['coordinates']) as List;
      if (coords.length < 2) return null;
      return coords
          .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
    } catch (e) {
      debugPrint('OSRM route error: $e');
      return null;
    } finally {
      _active--;
    }
  }
}
