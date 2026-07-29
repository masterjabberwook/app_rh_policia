import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

import 'geojson_loader.dart';
import 'models.dart';
import 'road_router.dart';
import 'theme.dart';
import 'voice.dart';

/// Frases/tipos de delito para alertas espontáneas (demo).
const _crimeTypes = [
  'Robo a transeúnte',
  'Riña en vía pública',
  'Persona sospechosa',
  'Accidente vial',
  'Alarma vecinal activada',
  'Disparos reportados',
  'Vehículo abandonado',
];

/// Estado global compartido (demo, en memoria). Singleton tipo store.
class AppStore extends ChangeNotifier {
  AppStore._();
  static final AppStore I = AppStore._();

  final _rng = Random();
  final _router = RoadRouter();
  static const _geo = Distance();

  final List<Cuadrante> cuadrantes = [];
  final List<Officer> officers = [];
  final List<Patrol> patrols = [];
  final List<CrimeReport> crimes = [];
  final List<DutyEvent> events = [];

  bool loaded = false;
  // Encuadre del mapa calculado de los polígonos reales.
  LatLng center = const LatLng(19.4785, -99.2370);
  LatLng boundsSW = const LatLng(19.41, -99.35);
  LatLng boundsNE = const LatLng(19.53, -99.20);

  Timer? _timer;
  Timer? _alertTimer;

  // Configuración de Firestore y sincronización
  final _db = FirebaseFirestore.instance;
  StreamSubscription? _officersSub;
  StreamSubscription? _patrolsSub;
  StreamSubscription? _crimesSub;
  StreamSubscription? _eventsSub;

  Officer? currentLocalOfficer;
  DateTime? _lastLocationReportTime;
  final DateTime _appStartTime = DateTime.now();
  final Set<String> _announcedEventIds = {};

  double _r() => _rng.nextDouble();

  Future<void> _log(DutyEvent e) async {
    try {
      await _db.collection('events').add({
        'time': Timestamp.fromDate(e.time),
        'officerName': e.officerName,
        'type': e.type.name,
        'detalle': e.detalle,
        'cuadrante': e.cuadrante,
        'channel': e.channel.name,
      });
    } catch (err) {
      debugPrint('Error al registrar evento en Firestore: $err');
    }
  }

  // -------- Carga + semilla --------
  Future<void> load() async {
    if (loaded) return;
    try {
      cuadrantes.addAll(await loadCuadrantes());
    } catch (e) {
      debugPrint('GeoJSON no disponible ($e). Uso cuadrantes de respaldo.');
    }
    if (cuadrantes.isEmpty) _seedFallbackCuadrantes();
    _computeBounds();

    // Asegurar que Firestore tenga datos para la demo
    await _checkAndSeedFirestore();

    // Obtener datos iniciales antes de marcar la app como cargada
    try {
      final snapDocs = await Future.wait([
        _db.collection('officers').get(),
        _db.collection('patrols').get(),
        _db.collection('crimes').get(),
      ]);

      // 1. Oficiales
      officers.clear();
      for (var doc in snapDocs[0].docs) {
        final data = doc.data();
        final pos = data['position'] as Map<String, dynamic>? ?? {'latitude': 19.4785, 'longitude': -99.2370};
        final checkInStr = data['checkIn'] as String?;
        officers.add(Officer(
          id: doc.id,
          nombre: data['nombre'] ?? '',
          rango: data['rango'] ?? '',
          placa: data['placa'] ?? '',
          unidad: data['unidad'] ?? '',
          cuadranteId: data['cuadranteId'] ?? '',
          status: DutyStatus.values.firstWhere(
            (s) => s.name == (data['status'] ?? 'offDuty'),
            orElse: () => DutyStatus.offDuty,
          ),
          position: LatLng(
            (pos['latitude'] as num).toDouble(),
            (pos['longitude'] as num).toDouble(),
          ),
          checkIn: checkInStr != null ? DateTime.parse(checkInStr) : null,
        ));
      }

      // 2. Patrullas
      patrols.clear();
      for (var doc in snapDocs[1].docs) {
        final id = doc.id;
        final data = doc.data();
        final pos = data['position'] as Map<String, dynamic>? ?? {'latitude': 19.4785, 'longitude': -99.2370};
        patrols.add(Patrol(
          id: id,
          label: data['label'] ?? '',
          cuadranteId: data['cuadranteId'] ?? '',
          position: LatLng(
            (pos['latitude'] as num).toDouble(),
            (pos['longitude'] as num).toDouble(),
          ),
          isOfficer: data['isOfficer'] ?? false,
          speed: (data['speed'] as num? ?? 0.0).toDouble(),
        )..heading = (data['heading'] as num? ?? 0.0).toDouble());
      }

      // 3. Delitos
      crimes.clear();
      for (var doc in snapDocs[2].docs) {
        final data = doc.data();
        final pos = data['position'] as Map<String, dynamic>? ?? {'latitude': 19.4785, 'longitude': -99.2370};
        crimes.add(CrimeReport(
          id: doc.id,
          tipo: data['tipo'] ?? '',
          position: LatLng(
            (pos['latitude'] as num).toDouble(),
            (pos['longitude'] as num).toDouble(),
          ),
          createdAt: data['createdAt'] != null
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
          tomadoPor: data['tomadoPor'],
          prioridad: data['prioridad'] ?? 2,
        ));
      }
    } catch (e) {
      debugPrint('Error al obtener datos iniciales de Firestore: $e');
    }

    // Iniciar escucha en tiempo real de Firestore
    _startFirestoreSync();

    // Arrancamos el timer para mover la patrulla en servicio localmente
    _timer = Timer.periodic(const Duration(milliseconds: 90), (_) => _step(0.09));
    
    // Alertas espontáneas periódicas escritas en Firestore
    _alertTimer = Timer.periodic(const Duration(seconds: 18), (_) => spawnAlert());

    loaded = true;
    notifyListeners();
  }

  void _startFirestoreSync() {
    // 1. Escucha en tiempo real de oficiales
    _officersSub = _db.collection('officers').snapshots().listen((snapshot) {
      officers.clear();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final pos = data['position'] as Map<String, dynamic>? ?? {'latitude': 19.4785, 'longitude': -99.2370};
        final checkInStr = data['checkIn'] as String?;
        officers.add(Officer(
          id: doc.id,
          nombre: data['nombre'] ?? '',
          rango: data['rango'] ?? '',
          placa: data['placa'] ?? '',
          unidad: data['unidad'] ?? '',
          cuadranteId: data['cuadranteId'] ?? '',
          status: DutyStatus.values.firstWhere(
            (s) => s.name == (data['status'] ?? 'offDuty'),
            orElse: () => DutyStatus.offDuty,
          ),
          position: LatLng(
            (pos['latitude'] as num).toDouble(),
            (pos['longitude'] as num).toDouble(),
          ),
          checkIn: checkInStr != null ? DateTime.parse(checkInStr) : null,
        ));
      }

      if (currentLocalOfficer != null) {
        final stillActive = officers.any((o) => o.id == currentLocalOfficer!.id && o.status == DutyStatus.active);
        if (!stillActive) {
          currentLocalOfficer = null;
        }
      } else {
        final activeOfficer = officers.cast<Officer?>().firstWhere(
          (o) => o?.status == DutyStatus.active,
          orElse: () => null,
        );
        if (activeOfficer != null) {
          currentLocalOfficer = activeOfficer;
        }
      }
      notifyListeners();
    });

    // 2. Escucha en tiempo real de patrullas
    _patrolsSub = _db.collection('patrols').snapshots().listen((snapshot) {
      final List<Patrol> newPatrols = [];
      for (var doc in snapshot.docs) {
        final id = doc.id;
        final data = doc.data();

        // Si es nuestra propia patrulla local simulada o una patrulla general, mantenemos su objeto local
        final localPatrol = patrols.cast<Patrol?>().firstWhere(
          (lp) => lp?.id == id,
          orElse: () => null,
        );

        if (localPatrol != null) {
          // Si el oficial local cambió de posición drásticamente en Firestore (otro cliente), sincronizamos
          if (id == 'ofc-${currentLocalOfficer?.id}') {
            // pero preferimos nuestra simulación local suave
          }
          newPatrols.add(localPatrol);
          continue;
        }

        final pos = data['position'] as Map<String, dynamic>? ?? {'latitude': 19.4785, 'longitude': -99.2370};
        newPatrols.add(Patrol(
          id: id,
          label: data['label'] ?? '',
          cuadranteId: data['cuadranteId'] ?? '',
          position: LatLng(
            (pos['latitude'] as num).toDouble(),
            (pos['longitude'] as num).toDouble(),
          ),
          isOfficer: data['isOfficer'] ?? false,
          speed: (data['speed'] as num? ?? 8.0).toDouble(),
        )..heading = (data['heading'] as num? ?? 0.0).toDouble());
      }

      // Actualización atómica de la lista para evitar parpadeos
      patrols.clear();
      patrols.addAll(newPatrols);
      notifyListeners();
    });

    // 3. Escucha en tiempo real de delitos
    _crimesSub = _db.collection('crimes').snapshots().listen((snapshot) {
      crimes.clear();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final pos = data['position'] as Map<String, dynamic>? ?? {'latitude': 19.4785, 'longitude': -99.2370};
        crimes.add(CrimeReport(
          id: doc.id,
          tipo: data['tipo'] ?? '',
          position: LatLng(
            (pos['latitude'] as num).toDouble(),
            (pos['longitude'] as num).toDouble(),
          ),
          createdAt: data['createdAt'] != null
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
          tomadoPor: data['tomadoPor'],
          prioridad: data['prioridad'] ?? 2,
        ));
      }
      notifyListeners();
    });

    // 4. Escucha en tiempo real de eventos (límitado a los últimos 40)
    _eventsSub = _db.collection('events').orderBy('time', descending: true).limit(40).snapshots().listen((snapshot) {
      events.clear();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final docId = doc.id;
        final ev = DutyEvent(
          time: data['time'] != null
              ? (data['time'] as Timestamp).toDate()
              : DateTime.now(),
          officerName: data['officerName'] ?? '',
          type: EventType.values.firstWhere(
            (t) => t.name == (data['type'] ?? 'alerta'),
            orElse: () => EventType.alerta,
          ),
          detalle: data['detalle'] ?? '',
          cuadrante: data['cuadrante'] ?? '',
          channel: Channel.values.firstWhere(
            (ch) => ch.name == (data['channel'] ?? 'app'),
            orElse: () => Channel.app,
          ),
        );
        events.add(ev);

        // Anunciar por voz solo si el evento ocurrió después de abrir la app y no ha sido anunciado aún
        if (ev.time.isAfter(_appStartTime) && !_announcedEventIds.contains(docId)) {
          _announcedEventIds.add(docId);
          VoiceService.I.announce(ev);
        }
      }
      notifyListeners();
    });
  }

  Future<void> _checkAndSeedFirestore() async {
    try {
      final snap = await _db.collection('officers').limit(1).get();
      if (snap.docs.isNotEmpty) return;

      debugPrint('Firestore vacío. Sembrando oficiales, patrullas y delitos...');

      final nombres = [
        ['Juan Pérez Ramírez', 'Oficial', 'P-1042', 'PT-118'],
        ['María López Soto', 'Suboficial', 'P-2087', 'PT-204'],
        ['Carlos Méndez Ruiz', 'Oficial', 'P-3311', 'PT-309'],
        ['Ana Torres Vega', 'Primer Of.', 'P-4456', 'PT-417'],
        ['Luis Hernández Cruz', 'Oficial', 'P-5590', 'PT-521'],
        ['Sofía Castro Núñez', 'Suboficial', 'P-6620', 'PT-633'],
      ];
      final stepC = max(1, cuadrantes.length ~/ nombres.length);
      for (var i = 0; i < nombres.length; i++) {
        final n = nombres[i];
        final cu = cuadrantes[(i * stepC) % cuadrantes.length];
        final pos = _randIn(cu);
        final oId = 'O$i';

        await _db.collection('officers').doc(oId).set({
          'nombre': n[0],
          'rango': n[1],
          'placa': n[2],
          'unidad': n[3],
          'cuadranteId': cu.id,
          'status': (i == 5 ? DutyStatus.absent : DutyStatus.offDuty).name,
          'position': {
            'latitude': pos.latitude,
            'longitude': pos.longitude,
          },
          'checkIn': null,
        });

        if (i == 1 || i == 2) {
          await _db.collection('officers').doc(oId).update({
            'status': DutyStatus.active.name,
            'checkIn': DateTime.now().subtract(Duration(minutes: 8 + _rng.nextInt(40))).toIso8601String(),
          });
          await _db.collection('patrols').doc('ofc-$oId').set({
            'label': n[3],
            'cuadranteId': cu.id,
            'position': {
              'latitude': pos.latitude,
              'longitude': pos.longitude,
            },
            'isOfficer': true,
            'speed': 1.4 + _r(),
            'heading': 0.0,
          });
        }
      }

      final nP = min(22, cuadrantes.length);
      for (var i = 0; i < nP; i++) {
        final cu = cuadrantes[i];
        final pos = _randIn(cu);
        await _db.collection('patrols').doc('PT$i').set({
          'label': 'PT-${100 + i * 7}',
          'cuadranteId': cu.id,
          'position': {
            'latitude': pos.latitude,
            'longitude': pos.longitude,
          },
          'isOfficer': false,
          'speed': 8.0 + _r() * 6.0,
          'heading': 0.0,
        });
      }

      for (var i = 0; i < 5; i++) {
        final cu = cuadrantes[_rng.nextInt(cuadrantes.length)];
        final pos = _randIn(cu);
        await _db.collection('crimes').doc('R$i').set({
          'tipo': _crimeTypes[i % _crimeTypes.length],
          'position': {
            'latitude': pos.latitude,
            'longitude': pos.longitude,
          },
          'createdAt': Timestamp.fromDate(DateTime.now().subtract(Duration(seconds: 10 + i * 40))),
          'prioridad': 1 + (i % 3),
          'tomadoPor': i == 4 ? 'PT-204' : null,
        });
      }

      await _db.collection('events').add({
        'time': Timestamp.fromDate(DateTime.now().subtract(const Duration(minutes: 4))),
        'officerName': 'Sistema',
        'type': EventType.alerta.name,
        'detalle': 'Turno matutino iniciado · Naucalpan',
        'cuadrante': '—',
        'channel': Channel.app.name,
      });
    } catch (err) {
      debugPrint('Error al sembrar Firestore: $err');
    }
  }

  void _reportLocation(Patrol p) {
    final now = DateTime.now();
    if (_lastLocationReportTime == null || now.difference(_lastLocationReportTime!).inSeconds >= 3) {
      _lastLocationReportTime = now;
      _db.collection('patrols').doc(p.id).set({
        'label': p.label,
        'cuadranteId': p.cuadranteId,
        'position': {
          'latitude': p.position.latitude,
          'longitude': p.position.longitude,
        },
        'isOfficer': p.isOfficer,
        'speed': p.speed,
        'heading': p.heading,
      }, SetOptions(merge: true)).catchError((e) {
        debugPrint('Error al reportar ubicación a Firestore: $e');
      });
    }
  }

  /// Respaldo si el asset GeoJSON no carga: 4 cuadrantes rectangulares.
  void _seedFallbackCuadrantes() {
    const n = 19.505, s = 19.450, w = -99.265, e = -99.205;
    const mLat = (n + s) / 2, mLng = (w + e) / 2;
    final palette = [AppColors.cyan, AppColors.teal, AppColors.blue, AppColors.green];
    final defs = [
      ['01', 'Centro', mLat, n, w, mLng],
      ['02', 'Norte', mLat, n, mLng, e],
      ['03', 'Sur', s, mLat, w, mLng],
      ['04', 'Oriente', s, mLat, mLng, e],
    ];
    for (var i = 0; i < defs.length; i++) {
      final d = defs[i];
      final south = d[2] as double, north = d[3] as double;
      final west = d[4] as double, east = d[5] as double;
      cuadrantes.add(Cuadrante(
        id: d[0] as String,
        nombre: 'Cuadrante ${d[1]}',
        corto: 'C${d[0]}',
        polygon: [
          LatLng(north, west), LatLng(north, east),
          LatLng(south, east), LatLng(south, west),
        ],
        centroid: LatLng((south + north) / 2, (west + east) / 2),
        sw: LatLng(south, west),
        ne: LatLng(north, east),
        color: palette[i],
      ));
    }
  }

  void _computeBounds() {
    if (cuadrantes.isEmpty) return;
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final c in cuadrantes) {
      minLat = min(minLat, c.sw.latitude);
      maxLat = max(maxLat, c.ne.latitude);
      minLng = min(minLng, c.sw.longitude);
      maxLng = max(maxLng, c.ne.longitude);
    }
    boundsSW = LatLng(minLat, minLng);
    boundsNE = LatLng(maxLat, maxLng);
    center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
  }

  Cuadrante cuadranteOf(String id) =>
      cuadrantes.firstWhere((c) => c.id == id, orElse: () => cuadrantes.first);

  LatLng _randIn(Cuadrante cu) => cu.randPoint(_r);



  void _step(double dt) {
    bool changed = false;
    if (currentLocalOfficer != null) {
      final myPatrolId = 'ofc-${currentLocalOfficer!.id}';
      final p = patrols.cast<Patrol?>().firstWhere((p) => p?.id == myPatrolId, orElse: () => null);
      if (p != null) {
        if (p.needsRoute) {
          _ensureRoute(p);
        } else {
          _advance(p, p.speed * dt);
          changed = true;
        }
        _reportLocation(p);
      }
    } else {
      for (final p in patrols) {
        if (!p.id.startsWith('ofc-')) {
          if (p.needsRoute) {
            _ensureRoute(p);
            continue;
          }
          _advance(p, p.speed * dt);
          changed = true;
        }
      }
    }
    if (changed) notifyListeners();
  }

  void _advance(Patrol p, double meters) {
    var remaining = meters;
    while (remaining > 0 && p.idx < p.route.length) {
      final target = p.route[p.idx];
      final segDist = _geo.distance(p.position, target);
      if (segDist <= 0.0001) {
        p.idx++;
        continue;
      }
      if (remaining >= segDist) {
        p.position = target;
        remaining -= segDist;
        p.idx++;
      } else {
        final brg = _geo.bearing(p.position, target);
        p.heading = brg;
        p.position = _geo.offset(p.position, remaining, brg);
        remaining = 0;
      }
    }
    if (p.idx >= p.route.length) p.route = const [];
  }

  void _ensureRoute(Patrol p) {
    if (p.routing || _router.busy) return;
    p.routing = true;
    final cu = cuadranteOf(p.cuadranteId);
    final dest = _randIn(cu);
    _router.route(p.position, dest).then((rt) {
      if (rt != null && rt.length >= 2) {
        p.route = rt;
        p.idx = 1;
      } else {
        p.route = _straight(p.position, dest, 24);
        p.idx = 1;
      }
      p.routing = false;
    });
  }

  List<LatLng> _straight(LatLng a, LatLng b, int n) => List.generate(
        n + 1,
        (i) => LatLng(
          a.latitude + (b.latitude - a.latitude) * i / n,
          a.longitude + (b.longitude - a.longitude) * i / n,
        ),
      );

  // -------- Acciones --------
  void startService(Officer o) {
    currentLocalOfficer = o;
    o.status = DutyStatus.active;
    o.checkIn = DateTime.now();
    
    final pId = 'ofc-${o.id}';
    
    // 1. Actualizar estado en Firestore
    _db.collection('officers').doc(o.id).update({
      'status': DutyStatus.active.name,
      'checkIn': o.checkIn!.toIso8601String(),
      'position': {
        'latitude': o.position.latitude,
        'longitude': o.position.longitude,
      },
    }).catchError((e) => debugPrint('Error al actualizar oficial: $e'));

    // 2. Crear patrulla del oficial en Firestore
    _db.collection('patrols').doc(pId).set({
      'label': o.unidad,
      'cuadranteId': o.cuadranteId,
      'position': {
        'latitude': o.position.latitude,
        'longitude': o.position.longitude,
      },
      'isOfficer': true,
      'speed': 1.5,
      'heading': 0.0,
    }).catchError((e) => debugPrint('Error al crear patrulla: $e'));
    
    // 3. Registrar evento
    _log(DutyEvent(
      time: DateTime.now(), officerName: o.nombre, type: EventType.entrada,
      detalle: 'Entro a servicio · Unidad ${o.unidad} · registro operativo confirmado',
      cuadrante: cuadranteOf(o.cuadranteId).nombre,
    ));
  }

  void endService(Officer o) {
    if (currentLocalOfficer?.id == o.id) {
      currentLocalOfficer = null;
    }
    o.status = DutyStatus.offDuty;
    o.checkIn = null;

    // 1. Actualizar estado en Firestore
    _db.collection('officers').doc(o.id).update({
      'status': DutyStatus.offDuty.name,
      'checkIn': null,
    }).catchError((e) => debugPrint('Error al dar de baja oficial: $e'));

    // 2. Eliminar patrulla de Firestore
    _db.collection('patrols').doc('ofc-${o.id}').delete().catchError((e) => debugPrint('Error al borrar patrulla: $e'));
    
    // 3. Registrar evento
    _log(DutyEvent(
      time: DateTime.now(), officerName: o.nombre, type: EventType.salida,
      detalle: 'Cerró turno · PIN validado',
      cuadrante: cuadranteOf(o.cuadranteId).nombre,
    ));
  }

  void takeCrime(CrimeReport c, Officer o) {
    c.tomadoPor = o.unidad;

    // 1. Marcar tomado en Firestore
    _db.collection('crimes').doc(c.id).update({
      'tomadoPor': o.unidad,
    }).catchError((e) => debugPrint('Error al tomar delito: $e'));

    // 2. Registrar evento
    _log(DutyEvent(
      time: DateTime.now(), officerName: o.nombre, type: EventType.reporteTomado,
      detalle: 'Tomó reporte: ${c.tipo}',
      cuadrante: cuadranteOf(o.cuadranteId).nombre,
    ));
  }

  void whatsappCheck(Officer o) {
    // Registrar evento de WhatsApp
    _log(DutyEvent(
      time: DateTime.now(),
      officerName: o.nombre,
      type: EventType.entrada,
      detalle: 'Checó por WhatsApp, ubicación compartida',
      cuadrante: cuadranteOf(o.cuadranteId).nombre,
      channel: Channel.whatsapp,
    ));
  }

  void spawnAlert() {
    final cu = cuadrantes[_rng.nextInt(cuadrantes.length)];
    final tipo = _crimeTypes[_rng.nextInt(_crimeTypes.length)];
    final newId = 'R${DateTime.now().millisecondsSinceEpoch}';
    final latLng = _randIn(cu);
    final prio = 1 + _rng.nextInt(3);

    // Crear reporte en Firestore
    _db.collection('crimes').doc(newId).set({
      'tipo': tipo,
      'position': {
        'latitude': latLng.latitude,
        'longitude': latLng.longitude,
      },
      'createdAt': Timestamp.fromDate(DateTime.now()),
      'prioridad': prio,
      'tomadoPor': null,
    }).catchError((e) => debugPrint('Error al crear alerta: $e'));

    // Registrar evento
    _log(DutyEvent(
      time: DateTime.now(), officerName: 'Central', type: EventType.alerta,
      detalle: 'Nuevo reporte: $tipo', cuadrante: cu.nombre,
    ));
  }

  // -------- Métricas RH --------
  int get activos => officers.where((o) => o.status == DutyStatus.active).length;
  int get fueraServicio => officers.where((o) => o.status == DutyStatus.offDuty).length;
  int get faltaron => officers.where((o) => o.status == DutyStatus.absent).length;
  int get reportesActivos => crimes.where((c) => c.tomadoPor == null).length;

  @override
  void dispose() {
    _timer?.cancel();
    _alertTimer?.cancel();
    _officersSub?.cancel();
    _patrolsSub?.cancel();
    _crimesSub?.cancel();
    _eventsSub?.cancel();
    super.dispose();
  }
}
