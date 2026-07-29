import 'dart:async';
import 'dart:math';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'models.dart';
import 'store.dart';
import 'theme.dart';
import 'voice.dart';
import 'widgets/tactical_map.dart';

enum Phase { offDuty, verifyingIn, instructions, active, verifyingOut }

class PoliceScreen extends StatefulWidget {
  const PoliceScreen({super.key});

  @override
  State<PoliceScreen> createState() => _PoliceScreenState();
}

class _PoliceScreenState extends State<PoliceScreen> {
  Phase phase = Phase.offDuty;
  late final Officer me = AppStore.I.officers.firstWhere(
    (o) => o.status == DutyStatus.offDuty,
    orElse: () => AppStore.I.officers.first,
  );

  Cuadrante get cu => AppStore.I.cuadranteOf(me.cuadranteId);

  void _toggle(bool on) {
    if (on) {
      setState(() => phase = Phase.verifyingIn);
    } else {
      setState(() => phase = Phase.verifyingOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: const Color(0xFF611232),
        titleSpacing: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 8),
            ClipOval(
              child: Image.asset(
                'assets/nau_logo.png',
                width: 24,
                height: 24,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              me.unidad,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(child: _statusChip()),
          ],
        ),
        actions: [
          const VoiceToggleButton(color: Colors.white),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (MediaQuery.of(context).size.width > 380)
                  const Text(
                    'Servicio',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: phase == Phase.active ||
                        phase == Phase.verifyingIn ||
                        phase == Phase.instructions,
                    activeColor: Colors.white,
                    activeTrackColor: Colors.white.withOpacity(0.3),
                    inactiveThumbColor: Colors.white54,
                    inactiveTrackColor: Colors.white12,
                    onChanged: (v) {
                      if (phase == Phase.offDuty && v) _toggle(true);
                      if (phase == Phase.active && !v) _toggle(false);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: _body(),
      ),
    );
  }

  Widget _statusChip() {
    final active = phase == Phase.active;
    final color = active ? AppColors.success : const Color(0xFFB5975E);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        active ? 'ACTIVO' : 'FUERA',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _body() {
    switch (phase) {
      case Phase.offDuty:
        return _OffDuty(me: me, cu: cu, key: const ValueKey('off'));
      case Phase.verifyingIn:
        return _Verifying(
          key: const ValueKey('vin'),
          cu: cu,
          title: 'Verificando tu ubicación',
          onDone: () => setState(() => phase = Phase.instructions),
        );
      case Phase.instructions:
        return _Instructions(
          key: const ValueKey('ins'),
          me: me,
          cu: cu,
          onActivate: () {
            AppStore.I.startService(me);
            setState(() => phase = Phase.active);
          },
        );
      case Phase.active:
        return _Active(key: const ValueKey('act'), me: me);
      case Phase.verifyingOut:
        return _CloseTurn(
          key: const ValueKey('out'),
          cu: cu,
          onConfirm: () {
            AppStore.I.endService(me);
            setState(() => phase = Phase.offDuty);
          },
          onCancel: () => setState(() => phase = Phase.active),
        );
    }
  }
}

// ----------------- Fuera de servicio -----------------
class _OffDuty extends StatelessWidget {
  final Officer me;
  final Cuadrante cu;
  const _OffDuty({super.key, required this.me, required this.cu});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Avatar
              Container(
                width: 90,
                height: 90,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFEFECE6),
                ),
                child: const Center(
                  child: Icon(Icons.person, size: 44, color: Color(0xFF6E565F)),
                ),
              ),
              const SizedBox(height: 14),
              // Name
              Text(
                me.nombre,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                  color: Color(0xFF611232),
                ),
              ),
              // Range and Placa
              Text(
                '${me.rango} · Placa ${me.placa}',
                style: const TextStyle(
                  color: Color(0xFF6E5F65),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 18),
              // Card Container
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEFECE6), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _kv('Unidad asignada', me.unidad, Icons.directions_car),
                    const Divider(height: 24, color: Color(0xFFEFECE6), thickness: 1),
                    _kv('Cuadrante', cu.nombre, Icons.map),
                    const Divider(height: 24, color: Color(0xFFEFECE6), thickness: 1),
                    _kv('Estado', 'Fuera de servicio', Icons.shield),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              // Centered Text
              const Text(
                'Activa el switch "En servicio" para iniciar tu checador.\nSe verificará tu ubicación contra tu cuadrante.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF6E5F65),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              // WhatsApp Button (Pill shape, guinda background, white text)
              ElevatedButton.icon(
                onPressed: () {
                  AppStore.I.whatsappCheck(me);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    backgroundColor: AppColors.whatsapp,
                    content: Text('Check enviado por WhatsApp ✓'),
                  ));
                },
                icon: const Icon(Icons.chat, color: Colors.white, size: 18),
                label: const Text(
                  'Checar por WhatsApp',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF611232),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _kv(String k, String v, IconData icon) {
  final isStatus = k == 'Estado';
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: Color(0xFFF7EBF0),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF611232)),
        ),
        const SizedBox(width: 12),
        Text(
          k,
          style: const TextStyle(
            color: Color(0xFF6E5F65),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        isStatus
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9EAEF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  v,
                  style: const TextStyle(
                    color: Color(0xFF611232),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              )
            : Text(
                v,
                style: const TextStyle(
                  color: Color(0xFF611232),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
      ],
    ),
  );
}

// ----------------- Verificación de ubicación (radar) -----------------
class _Verifying extends StatefulWidget {
  final Cuadrante cu;
  final String title;
  final VoidCallback onDone;
  const _Verifying({super.key, required this.cu, required this.title, required this.onDone});

  @override
  State<_Verifying> createState() => _VerifyingState();
}

class _VerifyingState extends State<_Verifying> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  final steps = [
    'Obteniendo señal GPS…',
    'Triangulando posición…',
    'Comparando con polígono del cuadrante…',
    'Confirmando identidad del elemento…',
  ];
  int done = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _t = Timer.periodic(const Duration(milliseconds: 750), (t) {
      setState(() => done++);
      if (done >= steps.length) {
        t.cancel();
        Future.delayed(const Duration(milliseconds: 600), widget.onDone);
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 220,
                height: 220,
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (_, _) => CustomPaint(painter: _RadarPainter(_c.value, AppColors.guinda)),
                ),
              ),
              const SizedBox(height: 24),
              Text(widget.title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Cuadrante objetivo: ${widget.cu.nombre}',
                  style: const TextStyle(color: AppColors.guinda, fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.panel,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.grid, width: 1.2),
                ),
                child: Column(
                  children: List.generate(steps.length, (i) {
                    final ok = i < done;
                    final cur = i == done;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          ok
                              ? const Icon(Icons.check_circle, color: AppColors.success, size: 18)
                              : cur
                                  ? const SizedBox(
                                      width: 16, height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.guinda))
                                  : const Icon(Icons.circle_outlined, color: AppColors.textDim, size: 18),
                          const SizedBox(width: 12),
                          Text(steps[i],
                              style: TextStyle(
                                  color: ok ? AppColors.text : AppColors.textDim,
                                  fontWeight: ok ? FontWeight.w600 : FontWeight.normal,
                                  fontSize: 13)),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double t;
  final Color color;
  _RadarPainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(c, r * i / 3,
          Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = color.withValues(alpha: 0.3));
    }
    canvas.drawLine(Offset(c.dx, 0), Offset(c.dx, size.height),
        Paint()..color = color.withValues(alpha: 0.2));
    canvas.drawLine(Offset(0, c.dy), Offset(size.width, c.dy),
        Paint()..color = color.withValues(alpha: 0.2));
    // barrido
    final sweep = t * 2 * pi;
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawArc(
      rect, sweep, 0.9, true,
      Paint()
        ..shader = SweepGradient(
          startAngle: sweep,
          endAngle: sweep + 0.9,
          colors: [color.withValues(alpha: 0.4), color.withValues(alpha: 0)],
        ).createShader(rect),
    );
    canvas.drawLine(c, c + Offset(cos(sweep), sin(sweep)) * r,
        Paint()..strokeWidth = 2..color = color);
    // blip
    final blip = c + Offset(cos(sweep - 0.5), sin(sweep - 0.5)) * r * 0.6;
    canvas.drawCircle(blip, 4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) => true;
}

// ----------------- Instrucciones + Selfie -----------------
class _Instructions extends StatefulWidget {
  final Officer me;
  final Cuadrante cu;
  final VoidCallback onActivate;
  const _Instructions({super.key, required this.me, required this.cu, required this.onActivate});

  @override
  State<_Instructions> createState() => _InstructionsState();
}

class _InstructionsState extends State<_Instructions> {
  String? imagePath;
  bool gpsShared = true;

  @override
  Widget build(BuildContext context) {
    final steps = [
      ('1', 'Baja de tu unidad', 'Estaciona y desciende de ${widget.me.unidad}.', Icons.directions_car),
      ('2', 'Toma tu selfie de inicio', 'Debe verse el número de patrulla y el cuadrante al fondo.', Icons.camera_alt),
      ('3', 'Mantén tu localización activa', 'No cierres la app; tu posición se comparte en vivo.', Icons.my_location),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.verified, color: AppColors.success),
                  SizedBox(width: 8),
                  Text('Ubicación verificada',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              const Text('Sigue las instrucciones para activar tu turno.',
                  style: TextStyle(color: AppColors.textDim)),
              const SizedBox(height: 16),
              ...steps.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: HudPanel(
                      glow: AppColors.guinda,
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppColors.guinda,
                            child: Text(s.$1,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.$2, style: const TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(s.$3, style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
                              ],
                            ),
                          ),
                          Icon(s.$4, color: AppColors.textDim),
                        ],
                      ),
                    ),
                  )),
              const SizedBox(height: 4),
              _SelfieCapture(
                me: widget.me,
                cu: widget.cu,
                imagePath: imagePath,
                onTaken: (path) => setState(() => imagePath = path),
              ),
              const SizedBox(height: 14),
              SwitchListTile(
                value: gpsShared,
                onChanged: (v) => setState(() => gpsShared = v),
                activeThumbColor: AppColors.success,
                contentPadding: EdgeInsets.zero,
                title: const Text('Compartir localización en vivo'),
                secondary: const Icon(Icons.my_location, color: AppColors.guinda),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: (imagePath != null && gpsShared) ? widget.onActivate : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.play_arrow),
                label: const Text('ACTIVAR SERVICIO',
                    style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelfieCapture extends StatefulWidget {
  final Officer me;
  final Cuadrante cu;
  final String? imagePath;
  final Function(String) onTaken;

  const _SelfieCapture({
    super.key,
    required this.me,
    required this.cu,
    required this.imagePath,
    required this.onTaken,
  });

  @override
  State<_SelfieCapture> createState() => _SelfieCaptureState();
}

class _SelfieCaptureState extends State<_SelfieCapture> with SingleTickerProviderStateMixin {
  late AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      maxWidth: 1000,
      imageQuality: 85,
    );
    if (photo != null) {
      widget.onTaken(photo.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final taken = widget.imagePath != null;
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: taken ? AppColors.success : AppColors.guinda.withOpacity(0.5), width: 1.5),
          color: Colors.black,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (taken)
              Image.file(File(widget.imagePath!), fit: BoxFit.cover)
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF101826), Color(0xFF0A1019)],
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.person_outline,
                    size: 68,
                    color: Colors.white.withOpacity(0.15),
                  ),
                ),
              ),

            if (taken)
              AnimatedBuilder(
                animation: _scanController,
                builder: (context, child) {
                  return Stack(
                    children: [
                      // Línea de escaneo
                      Positioned(
                        top: _scanController.value * MediaQuery.of(context).size.height * 0.3, // Aproximado para el AspectRatio
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            color: AppColors.oro,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.oro.withOpacity(0.5),
                                blurRadius: 10,
                                spreadRadius: 2,
                              )
                            ],
                          ),
                        ),
                      ),
                      // Texto de procesamiento
                      Positioned(
                        top: 40,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'PROCESANDO IDENTIDAD...',
                              style: TextStyle(
                                color: AppColors.oro,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

            // Corchetes de encuadre biométrico (esquinas doradas)
            Positioned(
              left: 12, top: 12,
              child: Container(
                width: 18, height: 18,
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.oro, width: 2.5),
                    left: BorderSide(color: AppColors.oro, width: 2.5),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 12, top: 12,
              child: Container(
                width: 18, height: 18,
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.oro, width: 2.5),
                    right: BorderSide(color: AppColors.oro, width: 2.5),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12, bottom: 12,
              child: Container(
                width: 18, height: 18,
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.oro, width: 2.5),
                    left: BorderSide(color: AppColors.oro, width: 2.5),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 12, bottom: 12,
              child: Container(
                width: 18, height: 18,
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.oro, width: 2.5),
                    right: BorderSide(color: AppColors.oro, width: 2.5),
                  ),
                ),
              ),
            ),

            // overlay datos
            Positioned(
              left: 20, top: 20,
              child: _tag('UNIDAD ${widget.me.unidad}', AppColors.cyan),
            ),
            Positioned(
              right: 20, top: 20,
              child: _tag(widget.cu.nombre.toUpperCase(), widget.cu.color),
            ),
            Positioned(
              left: 20, bottom: 20,
              child: _tag('GPS 19.4785,-99.2370', AppColors.green),
            ),

            if (taken)
              const Positioned(
                right: 20, bottom: 20,
                child: Icon(Icons.check_circle, color: AppColors.green, size: 28),
              ),

            // botón disparador o re-tomar
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 54, height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: AppColors.oro, width: 3.5),
                      boxShadow: [
                        BoxShadow(color: AppColors.oro.withOpacity(0.4), blurRadius: 10)
                      ],
                    ),
                    child: Icon(
                      taken ? Icons.refresh : Icons.camera_alt,
                      color: AppColors.guinda,
                      size: 22
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String s, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.75),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: c.withOpacity(0.8), width: 1),
        ),
        child: Text(s,
            style: TextStyle(color: c, fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      );
}

// ----------------- Servicio activo -----------------
class _Active extends StatelessWidget {
  final Officer me;
  const _Active({super.key, required this.me});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.08),
            border: const Border(bottom: BorderSide(color: AppColors.success, width: 1.5)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.gps_fixed, color: AppColors.success, size: 16),
              const SizedBox(width: 8),
              const Text('EN SERVICIO · transmitiendo ubicación',
                  style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.3)),
              const Spacer(),
              Text('Inicio ${_hhmm(me.checkIn!)}',
                  style: const TextStyle(color: AppColors.textDim, fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        Expanded(
          flex: 2, // Reducimos el peso del mapa (antes ocupaba todo el espacio restante)
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: TacticalMap(
              self: me,
              onTapCrime: (c) => _showCrime(context, c, me),
            ),
          ),
        ),
        Expanded(
          flex: 3, // Damos más espacio a los reportes (antes era un tamaño fijo de 154)
          child: AnimatedBuilder(
            animation: AppStore.I,
            builder: (_, _) {
              final crimes = AppStore.I.crimes;
              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8, left: 4, top: 8),
                    child: Text('REPORTES CERCANOS',
                        style: TextStyle(color: AppColors.textDim, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                  ),
                  ...crimes.map((c) => _crimeTile(context, c, me)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _crimeTile(BuildContext context, CrimeReport c, Officer me) {
    final taken = c.tomadoPor != null;
    final col = taken ? AppColors.success : (c.reciente ? AppColors.danger : AppColors.warn);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: AppColors.grid, width: 1.2),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: col.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(taken ? Icons.assignment_turned_in : Icons.report, color: col, size: 20),
        ),
        title: Text(c.tipo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: AppColors.text)),
        subtitle: Text(
          taken
              ? 'Atendido por ${c.tomadoPor}'
              : 'Hace ${c.antiguedad.inSeconds}s · Prioridad ${c.prioridad}',
          style: const TextStyle(color: AppColors.textDim, fontSize: 12),
        ),
        trailing: taken
            ? const Icon(Icons.check_circle, color: AppColors.success, size: 24)
            : FilledButton(
                onPressed: () => AppStore.I.takeCrime(c, me),
                style: FilledButton.styleFrom(
                  backgroundColor: col,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                child: const Text('Tomar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
      ),
    );
  }

  void _showCrime(BuildContext context, CrimeReport c, Officer me) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.panel,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c.tipo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Antigüedad: ${c.antiguedad.inSeconds}s'),
            Text('Prioridad: ${c.prioridad}'),
            Text(c.tomadoPor == null ? 'Estado: libre' : 'Tomado por ${c.tomadoPor}'),
            const SizedBox(height: 16),
            if (c.tomadoPor == null)
              FilledButton.icon(
                onPressed: () {
                  AppStore.I.takeCrime(c, me);
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.flag),
                label: const Text('Tomar reporte'),
              ),
          ],
        ),
      ),
    );
  }
}

String _hhmm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

// ----------------- Cierre de turno (PIN) -----------------
class _CloseTurn extends StatefulWidget {
  final Cuadrante cu;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  const _CloseTurn({super.key, required this.cu, required this.onConfirm, required this.onCancel});

  @override
  State<_CloseTurn> createState() => _CloseTurnState();
}

class _CloseTurnState extends State<_CloseTurn> {
  String pin = '';
  bool locVerified = false;
  static const correct = '1234';

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1200),
        () => mounted ? setState(() => locVerified = true) : null);
  }

  void _tap(String d) {
    if (pin.length >= 4) return;
    setState(() => pin += d);
    if (pin.length == 4) {
      if (pin == correct) {
        Future.delayed(const Duration(milliseconds: 250), widget.onConfirm);
      } else {
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted) {
            setState(() => pin = '');
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              backgroundColor: AppColors.danger,
              content: Text('PIN incorrecto. Demo: 1234'),
            ));
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.oro.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.oro.withOpacity(0.4), width: 1.5),
                ),
                child: const Icon(Icons.lock, color: AppColors.oro, size: 36),
              ),
              const SizedBox(height: 14),
              const Text('Cierre de turno',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.guinda, letterSpacing: 0.2)),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  locVerified
                      ? const Icon(Icons.check_circle, color: AppColors.success, size: 18)
                      : const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.guinda)),
                  const SizedBox(width: 8),
                  Text(
                    locVerified
                        ? 'Dentro de ${widget.cu.nombre}'
                        : 'Verificando que sigas en tu cuadrante…',
                    style: TextStyle(color: locVerified ? AppColors.success : AppColors.textDim, fontWeight: FontWeight.w500, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Ingresa tu PIN de seguridad de cierre',
                  style: TextStyle(color: AppColors.textDim, fontWeight: FontWeight.w500, fontSize: 13.5)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final filled = i < pin.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 16, height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? AppColors.guinda : Colors.transparent,
                      border: Border.all(color: filled ? AppColors.guinda : AppColors.oro, width: 1.5),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 22),
              _PinPad(enabled: locVerified, onTap: _tap, onDel: () {
                if (pin.isNotEmpty) setState(() => pin = pin.substring(0, pin.length - 1));
              }),
              const SizedBox(height: 14),
              TextButton(
                onPressed: widget.onCancel,
                child: const Text('Cancelar', style: TextStyle(color: AppColors.textDim)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinPad extends StatelessWidget {
  final bool enabled;
  final void Function(String) onTap;
  final VoidCallback onDel;
  const _PinPad({required this.enabled, required this.onTap, required this.onDel});

  @override
  Widget build(BuildContext context) {
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'];
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.6,
        children: keys.map((k) {
          if (k.isEmpty) return const SizedBox();
          return InkWell(
            onTap: !enabled ? null : (k == '⌫' ? onDel : () => onTap(k)),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.panel,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.grid, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Center(
                child: Text(k, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.guinda)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
