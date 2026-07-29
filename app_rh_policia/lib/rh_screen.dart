import 'package:flutter/material.dart';

import 'models.dart';
import 'store.dart';
import 'theme.dart';
import 'voice.dart';
import 'widgets/tactical_map.dart';

class RhScreen extends StatelessWidget {
  const RhScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.panel,
        titleSpacing: 0,
        title: const Padding(
          padding: EdgeInsets.only(left: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.dashboard, color: AppColors.oro, size: 20),
              SizedBox(width: 8),
              Flexible(
                child: Text('Centro de Mando · RH',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
              ),
            ],
          ),
        ),
        actions: [
          const VoiceToggleButton(),
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.08),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.success.withOpacity(0.3), width: 1),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, color: AppColors.success, size: 6),
                SizedBox(width: 4),
                Text('EN VIVO', style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ],
            ),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: AppStore.I,
        builder: (context, _) {
          final wide = MediaQuery.of(context).size.width > 900;
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _stats(),
                const SizedBox(height: 12),
                Expanded(
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Expanded(flex: 3, child: _MapPanel()),
                            const SizedBox(width: 12),
                            Expanded(flex: 2, child: _sidePanels()),
                          ],
                        )
                      : Column(
                          children: [
                            const Expanded(flex: 3, child: _MapPanel()),
                            const SizedBox(height: 12),
                            Expanded(flex: 2, child: _sidePanels()),
                          ],
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _stats() {
    final s = AppStore.I;
    final cards = [
      ('Activos en servicio', s.activos, AppColors.success, Icons.gps_fixed),
      ('Fuera de servicio', s.fueraServicio, AppColors.textDim, Icons.power_settings_new),
      ('Faltaron', s.faltaron, AppColors.danger, Icons.person_off),
      ('Reportes activos', s.reportesActivos, AppColors.warn, Icons.report),
    ];
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 900 ? 4 : (c.maxWidth > 450 ? 2 : 2);
      final spacing = 10.0;
      final w = (c.maxWidth - (cols - 1) * spacing) / cols;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: cards
            .map((x) => SizedBox(
                  width: w,
                  child: _StatCard(title: x.$1, value: x.$2, color: x.$3, icon: x.$4),
                ))
            .toList(),
      );
    });
  }

  Widget _sidePanels() {
    return const Column(
      children: [
        Expanded(flex: 3, child: _LiveFeed()),
        SizedBox(height: 12),
        Expanded(flex: 2, child: _Roster()),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final int value;
  final Color color;
  final IconData icon;
  const _StatCard({required this.title, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return HudPanel(
      glow: color,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withOpacity(0.3), width: 1.2),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 0, end: value),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.easeOutCubic,
                  builder: (context, val, _) {
                    return Text('$val',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.5));
                  },
                ),
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textDim, fontSize: 11.5, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPanel extends StatelessWidget {
  const _MapPanel();

  @override
  Widget build(BuildContext context) {
    return HudPanel(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 10),
            child: Row(
              children: [
                Icon(Icons.public, size: 16, color: AppColors.oro),
                SizedBox(width: 8),
                Text('MAPA UNIVERSAL · unidades en tiempo real',
                    style: TextStyle(fontSize: 11.5, letterSpacing: 1, color: AppColors.textDim, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Expanded(child: TacticalMap()),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            children: [
              _legend(AppColors.teal, 'Patrulla'),
              _legend(AppColors.cyan, 'Elemento a pie'),
              _legend(AppColors.red, 'Delito reciente'),
              _legend(AppColors.amber, 'Delito previo'),
              _legend(AppColors.green, 'Atendido'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(Color c, String s) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(s, style: const TextStyle(fontSize: 11, color: AppColors.textDim)),
        ],
      );
}

class _LiveFeed extends StatelessWidget {
  const _LiveFeed();

  @override
  Widget build(BuildContext context) {
    final events = AppStore.I.events;
    return HudPanel(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.notifications_active, size: 16, color: AppColors.oro),
              SizedBox(width: 8),
              Text('CHECADOR · eventos en vivo',
                  style: TextStyle(fontSize: 11.5, letterSpacing: 1, color: AppColors.textDim, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: events.isEmpty
                ? const Center(child: Text('Sin eventos', style: TextStyle(color: AppColors.textDim)))
                : ListView.separated(
                    itemCount: events.length,
                    separatorBuilder: (_, _) => const Divider(height: 12, color: AppColors.grid),
                    itemBuilder: (_, i) => _eventRow(events[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _eventRow(DutyEvent e) {
    final map = {
      EventType.entrada: (AppColors.success, Icons.login),
      EventType.salida: (AppColors.textDim, Icons.logout),
      EventType.reporteTomado: (AppColors.warn, Icons.assignment),
      EventType.alerta: (AppColors.info, Icons.info),
    };
    final (color, icon) = map[e.type]!;
    final isNew = DateTime.now().difference(e.time).inSeconds < 10;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: isNew ? 1.0 : 0.0, end: 0.0),
      duration: const Duration(seconds: 8),
      builder: (context, opacity, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: color.withOpacity(opacity * 0.1),
            boxShadow: opacity > 0.01 ? [
              BoxShadow(color: color.withOpacity(opacity * 0.3), blurRadius: 10 * opacity)
            ] : null,
          ),
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
          child: child,
        );
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color.withOpacity(0.3), width: 1),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(e.officerName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.text)),
                    ),
                    if (e.channel == Channel.whatsapp)
                      const Icon(Icons.chat, size: 13, color: AppColors.whatsapp),
                    const SizedBox(width: 6),
                    Text(_hhmmss(e.time),
                        style: const TextStyle(color: AppColors.textDim, fontSize: 11, fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(e.detalle, style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
                const SizedBox(height: 2),
                Text(e.cuadrante, style: const TextStyle(color: AppColors.guinda, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _hhmmss(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
}

class _Roster extends StatelessWidget {
  const _Roster();

  @override
  Widget build(BuildContext context) {
    final officers = AppStore.I.officers;
    return HudPanel(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.groups, size: 16, color: AppColors.oro),
              SizedBox(width: 8),
              Text('ESTADO DE FUERZA',
                  style: TextStyle(fontSize: 11.5, letterSpacing: 1, color: AppColors.textDim, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: officers.length,
              itemBuilder: (_, i) => _row(officers[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(Officer o) {
    final m = {
      DutyStatus.active: (AppColors.success, 'Activo'),
      DutyStatus.offDuty: (AppColors.textDim, 'Fuera'),
      DutyStatus.verifying: (AppColors.info, 'Verificando'),
      DutyStatus.absent: (AppColors.danger, 'Faltó'),
    };
    final (color, label) = m[o.status]!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1),
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.4), blurRadius: 4)
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.nombre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.text)),
                const SizedBox(height: 1),
                Text('${o.unidad} · ${o.rango}',
                    style: const TextStyle(color: AppColors.textDim, fontSize: 11, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color.withOpacity(0.35), width: 1),
            ),
            child: Text(label, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
          ),
        ],
      ),
    );
  }
}
