import 'dart:ui';

import 'package:latlong2/latlong.dart';

/// Estado operativo de un elemento.
enum DutyStatus { offDuty, verifying, active, absent }

/// Canal por el que se registra un evento (app o WhatsApp).
enum Channel { app, whatsapp }

/// Tipo de evento de checador.
enum EventType { entrada, salida, reporteTomado, alerta }

/// Cuadrante real cargado del GeoJSON oficial de Naucalpan.
class Cuadrante {
  final String id; // '01'
  final String nombre; // 'Cuadrante 01'
  final String corto; // 'C01'
  final List<LatLng> polygon; // anillo exterior
  final LatLng centroid;
  final LatLng sw; // bbox min
  final LatLng ne; // bbox max
  final String? sector;
  final String? autoridad;
  final String? responsable;
  final String? telefono;
  final Color color;

  const Cuadrante({
    required this.id,
    required this.nombre,
    required this.corto,
    required this.polygon,
    required this.centroid,
    required this.sw,
    required this.ne,
    required this.color,
    this.sector,
    this.autoridad,
    this.responsable,
    this.telefono,
  });

  /// Punto dentro del polígono real (rechazo sobre bbox; cae al centroide).
  LatLng randPoint(double Function() rnd) {
    for (var i = 0; i < 40; i++) {
      final lat = sw.latitude + rnd() * (ne.latitude - sw.latitude);
      final lng = sw.longitude + rnd() * (ne.longitude - sw.longitude);
      final p = LatLng(lat, lng);
      if (contains(p)) return p;
    }
    return centroid;
  }

  /// Ray casting para saber si un punto está dentro del polígono.
  bool contains(LatLng p) {
    var inside = false;
    final n = polygon.length;
    for (var i = 0, j = n - 1; i < n; j = i++) {
      final xi = polygon[i].longitude, yi = polygon[i].latitude;
      final xj = polygon[j].longitude, yj = polygon[j].latitude;
      final intersect = ((yi > p.latitude) != (yj > p.latitude)) &&
          (p.longitude < (xj - xi) * (p.latitude - yi) / (yj - yi) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }
}

class Officer {
  final String id;
  final String nombre;
  final String rango;
  final String placa;
  final String unidad; // número de patrulla
  final String cuadranteId;
  DutyStatus status;
  LatLng position;
  DateTime? checkIn;

  Officer({
    required this.id,
    required this.nombre,
    required this.rango,
    required this.placa,
    required this.unidad,
    required this.cuadranteId,
    this.status = DutyStatus.offDuty,
    required this.position,
    this.checkIn,
  });
}

/// Unidad que patrulla siguiendo calles reales (ruta OSRM).
class Patrol {
  final String id;
  final String label;
  final String cuadranteId;
  LatLng position;
  bool isOfficer; // true = elemento a pie

  // Motor de movimiento por carretera.
  List<LatLng> route = const [];
  int idx = 0; // índice del próximo vértice objetivo en route
  double speed; // m/s
  bool routing = false; // hay petición de ruta en curso
  double heading = 0; // grados, para orientar el ícono

  Patrol({
    required this.id,
    required this.label,
    required this.cuadranteId,
    required this.position,
    this.isOfficer = false,
    required this.speed,
  });

  bool get needsRoute => route.length < 2 || idx >= route.length;
  List<LatLng> get remaining =>
      (idx > 0 && idx <= route.length) ? route.sublist(idx - 1) : route;
}

class CrimeReport {
  final String id;
  final String tipo;
  LatLng position;
  final DateTime createdAt;
  String? tomadoPor;
  final int prioridad;

  CrimeReport({
    required this.id,
    required this.tipo,
    required this.position,
    required this.createdAt,
    this.tomadoPor,
    this.prioridad = 2,
  });

  Duration get antiguedad => DateTime.now().difference(createdAt);
  bool get reciente => antiguedad.inSeconds < 45;
}

class DutyEvent {
  final DateTime time;
  final String officerName;
  final EventType type;
  final String detalle;
  final String cuadrante;
  final Channel channel;

  DutyEvent({
    required this.time,
    required this.officerName,
    required this.type,
    required this.detalle,
    required this.cuadrante,
    this.channel = Channel.app,
  });
}
