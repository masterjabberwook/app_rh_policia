import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'models.dart';

/// Narrador de alertas por texto a voz (español).
/// Encapsula FlutterTts y una cola para no encimar frases.
class VoiceService {
  VoiceService._();
  static final VoiceService I = VoiceService._();

  final FlutterTts _tts = FlutterTts();
  final ValueNotifier<bool> enabled = ValueNotifier(true);

  bool _ready = false;
  bool _speaking = false;
  final List<String> _queue = [];

  Future<void> init() async {
    if (_ready) return;
    try {
      await _tts.setLanguage('es-MX');
      await _tts.setSpeechRate(0.52);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      _tts.setCompletionHandler(() {
        _speaking = false;
        _next();
      });
      _tts.setErrorHandler((_) {
        _speaking = false;
        _next();
      });
      _ready = true;
    } catch (e) {
      debugPrint('TTS init error: $e');
    }
  }

  void toggle() => enabled.value = !enabled.value;

  /// Encola una frase para narrar.
  Future<void> say(String text) async {
    if (!enabled.value) return;
    await init();
    _queue.add(text);
    if (!_speaking) _next();
  }

  Future<void> _next() async {
    if (_speaking || _queue.isEmpty || !enabled.value) {
      if (!enabled.value) _queue.clear();
      return;
    }
    _speaking = true;
    final text = _queue.removeAt(0);
    _chirp();
    try {
      await _tts.speak(text);
    } catch (_) {
      _speaking = false;
      _next();
    }
  }

  /// Tono corto del sistema antes de hablar (donde esté disponible).
  void _chirp() {
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.lightImpact();
  }

  /// Narra un evento del checador con frase natural.
  void announce(DutyEvent e) {
    if (!enabled.value) return;
    final cuad = e.cuadrante == '—' ? '' : ' en ${e.cuadrante}';
    switch (e.type) {
      case EventType.entrada:
        final canal = e.channel == Channel.whatsapp ? 'por WhatsApp' : '';
        say('${e.officerName} entró a servicio $canal$cuad.');
        break;
      case EventType.salida:
        say('${e.officerName} cerró turno$cuad.');
        break;
      case EventType.reporteTomado:
        say('Reporte atendido. ${e.detalle}$cuad.');
        break;
      case EventType.alerta:
        say('Atención. ${e.detalle}$cuad.');
        break;
    }
  }
}

/// Botón de bocina para activar/silenciar la narración por voz.
class VoiceToggleButton extends StatelessWidget {
  final Color? color;
  const VoiceToggleButton({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: VoiceService.I.enabled,
      builder: (context, on, _) {
        return IconButton(
          tooltip: on ? 'Silenciar narración' : 'Activar narración por voz',
          onPressed: () {
            VoiceService.I.toggle();
            if (VoiceService.I.enabled.value) {
              VoiceService.I.say('Narración por voz activada.');
            }
          },
          icon: Icon(on ? Icons.volume_up : Icons.volume_off),
          color: color ?? (on ? const Color(0xFF611232) : const Color(0xFF7A6670)),
        );
      },
    );
  }
}
