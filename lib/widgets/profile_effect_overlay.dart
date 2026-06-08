import 'dart:math' as math;
import 'package:flutter/material.dart';

class ProfileEffectOverlay extends StatefulWidget {
  final String effect;
  final Color color;
  const ProfileEffectOverlay({super.key, required this.effect, required this.color});

  @override
  State<ProfileEffectOverlay> createState() => _ProfileEffectOverlayState();
}

class _ProfileEffectOverlayState extends State<ProfileEffectOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  static const _animated = {'sparkles', 'bokeh', 'particles', 'petals', 'fireflies', 'rain', 'snow', 'waves', 'ink'};

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 8));
    if (_animated.contains(widget.effect)) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(ProfileEffectOverlay old) {
    super.didUpdateWidget(old);
    if (old.effect != widget.effect) {
      if (_animated.contains(widget.effect)) {
        _ctrl.repeat();
      } else {
        _ctrl.stop();
        _ctrl.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (ctx, child) => CustomPaint(
            painter: ProfileEffectPainter(effect: widget.effect, t: _ctrl.value, color: widget.color),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class ProfileEffectPainter extends CustomPainter {
  final String effect;
  final double t;
  final Color color;

  static final _rng = math.Random(42);
  static final _px  = List.generate(30, (_) => _rng.nextDouble());
  static final _py  = List.generate(30, (_) => _rng.nextDouble());
  static final _sz  = List.generate(30, (_) => 1.5 + _rng.nextDouble() * 3.0);
  static final _ph  = List.generate(30, (_) => _rng.nextDouble() * math.pi * 2);
  static final _sp  = List.generate(30, (_) => 0.3 + _rng.nextDouble() * 0.7);
  static final _ang = List.generate(30, (_) => _rng.nextDouble() * math.pi * 2);

  const ProfileEffectPainter({required this.effect, required this.t, required this.color});

  @override
  bool shouldRepaint(ProfileEffectPainter old) =>
      old.t != t || old.effect != effect || old.color != color;

  @override
  void paint(Canvas canvas, Size size) {
    switch (effect) {
      case 'sparkles':  _sparkles(canvas, size);
      case 'bokeh':     _bokeh(canvas, size);
      case 'particles': _particles(canvas, size);
      case 'petals':    _petals(canvas, size);
      case 'fireflies': _fireflies(canvas, size);
      case 'rain':      _rain(canvas, size);
      case 'snow':      _snow(canvas, size);
      case 'waves':     _waves(canvas, size);
      case 'ink':       _ink(canvas, size);
    }
  }

  void _sparkles(Canvas canvas, Size size) {
    final p = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 18; i++) {
      final pulse = (math.sin(t * math.pi * 2 * _sp[i] + _ph[i]) + 1) / 2;
      final scale = 0.5 + pulse * 0.7;
      p.color = color.withValues(alpha: (0.12 + pulse * 0.52).clamp(0.0, 1.0));
      _drawStar(canvas, p, Offset(_px[i] * size.width, _py[i] * size.height), (_sz[i] + 1) * scale);
    }
  }

  void _bokeh(Canvas canvas, Size size) {
    for (int i = 0; i < 12; i++) {
      final pulse = (math.sin(t * math.pi * 2 * _sp[i] * 0.4 + _ph[i]) + 1) / 2;
      final c = Offset(_px[i] * size.width, _py[i] * size.height);
      final r = (6.0 + _sz[i] * 4) * (0.65 + pulse * 0.45);
      canvas.drawCircle(c, r, Paint()..color = color.withValues(alpha: 0.03 + pulse * 0.08));
      canvas.drawCircle(c, r, Paint()
        ..color = color.withValues(alpha: 0.07 + pulse * 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6 + pulse * 0.5);
    }
  }

  void _particles(Canvas canvas, Size size) {
    final p = Paint();
    for (int i = 0; i < 22; i++) {
      final wave = math.sin(t * math.pi * 2 + _ph[i]) * 14;
      final rise = ((t * _sp[i] + _ph[i] / (math.pi * 2)) % 1.0);
      final x    = _px[i] * size.width + wave * 0.4;
      final y    = _py[i] * size.height - rise * size.height * 0.35 + wave;
      final fade = math.sin(rise * math.pi).clamp(0.0, 1.0);
      p.color = color.withValues(alpha: (fade * 0.55).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), _sz[i] * 0.75, p);
    }
  }

  void _petals(Canvas canvas, Size size) {
    for (int i = 0; i < 15; i++) {
      final fall = ((t * _sp[i] + _ph[i] / (math.pi * 2)) % 1.0);
      final x    = _px[i] * size.width + math.sin(fall * math.pi * 4 + _ph[i]) * 18;
      final y    = fall * (size.height + 16) - 8;
      final rot  = _ang[i] + fall * math.pi * 3;
      final fade = math.sin(fall * math.pi).clamp(0.0, 1.0);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot);
      final path = Path()
        ..moveTo(0, -4)
        ..cubicTo(3, -2, 3.5, 1.5, 0, 4)
        ..cubicTo(-3.5, 1.5, -3, -2, 0, -4);
      canvas.drawPath(path, Paint()
        ..color = color.withValues(alpha: (fade * 0.55).clamp(0.0, 1.0)));
      canvas.restore();
    }
  }

  void _fireflies(Canvas canvas, Size size) {
    for (int i = 0; i < 14; i++) {
      final dx    = math.sin(t * math.pi * 2 * _sp[i] + _ph[i]) * 22;
      final dy    = math.cos(t * math.pi * 2 * _sp[i] + _ph[i] + 1) * 14;
      final cx    = _px[i] * size.width + dx;
      final cy    = _py[i] * size.height + dy;
      final pulse = (math.sin(t * math.pi * 5 + _ph[i]) + 1) / 2;
      final r     = _sz[i] * 0.85;
      canvas.drawCircle(Offset(cx, cy), r * 4, Paint()..color = color.withValues(alpha: pulse * 0.09));
      canvas.drawCircle(Offset(cx, cy), r * 2, Paint()..color = color.withValues(alpha: pulse * 0.18));
      canvas.drawCircle(Offset(cx, cy), r,     Paint()..color = color.withValues(alpha: 0.55 + pulse * 0.45));
    }
  }

  void _rain(Canvas canvas, Size size) {
    final p = Paint()..strokeWidth = 0.75;
    for (int i = 0; i < 28; i++) {
      final fall = ((t * _sp[i] * 1.6 + _ph[i] / (math.pi * 2)) % 1.0);
      final x    = _px[i] * size.width;
      final y    = fall * (size.height + 18) - 9;
      final len  = 7.0 + _sz[i] * 2.5;
      final fade = math.sin(fall * math.pi).clamp(0.0, 1.0);
      p.color = color.withValues(alpha: (fade * 0.32).clamp(0.0, 1.0));
      canvas.drawLine(Offset(x, y), Offset(x - 1.5, y + len), p);
    }
  }

  void _snow(Canvas canvas, Size size) {
    final p = Paint();
    for (int i = 0; i < 20; i++) {
      final drift = math.sin(t * math.pi * 2 + _ph[i]) * 10;
      final fall  = ((t * _sp[i] * 0.55 + _ph[i] / (math.pi * 2)) % 1.0);
      final x     = _px[i] * size.width + drift;
      final y     = fall * (size.height + 10) - 5;
      final fade  = math.sin(fall * math.pi).clamp(0.0, 1.0);
      p.color = color.withValues(alpha: (fade * 0.65).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), _sz[i] * 0.7, p);
    }
  }

  void _waves(Canvas canvas, Size size) {
    for (int w = 0; w < 3; w++) {
      final baseY = size.height * (0.28 + w * 0.24);
      final path  = Path()..moveTo(0, baseY);
      for (double x = 0; x <= size.width; x += 2) {
        final y = baseY + math.sin((x / size.width * math.pi * 3.5) + t * math.pi * 2 + w * 1.3) * 11;
        path.lineTo(x, y);
      }
      canvas.drawPath(path, Paint()
        ..color = color.withValues(alpha: 0.10 + w * 0.05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5);
    }
  }

  void _ink(Canvas canvas, Size size) {
    // قطرات حبر تتسع كدوائر ماء ثم تتلاشى
    for (int i = 0; i < 12; i++) {
      final phase  = ((t * _sp[i] * 0.6 + _ph[i] / (math.pi * 2)) % 1.0);
      final fade   = (1.0 - phase).clamp(0.0, 1.0);
      final maxR   = 6.0 + _sz[i] * 6;
      final r      = phase * maxR;
      final cx     = _px[i] * size.width;
      final cy     = _py[i] * size.height;
      // الحلقة الخارجية المتسعة
      canvas.drawCircle(Offset(cx, cy), r, Paint()
        ..color = color.withValues(alpha: (fade * 0.28).clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0 + fade * 1.8);
      // نقطة صغيرة في المركز تظهر عند البداية فقط
      if (phase < 0.25) {
        final coreFade = (1 - phase / 0.25).clamp(0.0, 1.0);
        canvas.drawCircle(Offset(cx, cy), 2.5 * coreFade, Paint()
          ..color = color.withValues(alpha: (coreFade * 0.55).clamp(0.0, 1.0)));
      }
    }
  }

  void _drawStar(Canvas canvas, Paint paint, Offset c, double s) {
    final path = Path();
    for (int i = 0; i < 8; i++) {
      final a = i * math.pi / 4 - math.pi / 2;
      final r = i.isEven ? s : s * 0.38;
      final p = Offset(c.dx + math.cos(a) * r, c.dy + math.sin(a) * r);
      if (i == 0) path.moveTo(p.dx, p.dy); else path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }
}
