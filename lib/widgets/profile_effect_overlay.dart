import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class ProfileEffectOverlay extends StatefulWidget {
  final String effect;
  final Color color;
  const ProfileEffectOverlay({super.key, required this.effect, required this.color});

  @override
  State<ProfileEffectOverlay> createState() => _ProfileEffectOverlayState();
}

class _ProfileEffectOverlayState extends State<ProfileEffectOverlay>
    with SingleTickerProviderStateMixin {

  late Ticker _ticker;
  double _t = 0; // elapsed seconds — grows forever, no reset

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      if (mounted) setState(() => _t = elapsed.inMilliseconds / 1000.0);
    });
    if (widget.effect != 'none') _ticker.start();
  }

  @override
  void didUpdateWidget(ProfileEffectOverlay old) {
    super.didUpdateWidget(old);
    if (old.effect != widget.effect) {
      if (widget.effect == 'none') {
        _ticker.stop();
      } else if (!_ticker.isActive) {
        _ticker.start();
      }
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: ProfileEffectPainter(effect: widget.effect, t: _t, color: widget.color),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

// ── Painter ──────────────────────────────────────────────────────────────────
// t = elapsed seconds (grows forever — no wrap glitch)

class ProfileEffectPainter extends CustomPainter {
  final String effect;
  final double t;
  final Color color;

  // ثوابت عشوائية مُولَّدة مرة واحدة (seed=42 → نفس القيم دائماً)
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

  // ── بريق — نجوم تومض بتردد طبيعي ───────────────────────────────────────
  void _sparkles(Canvas canvas, Size size) {
    final p = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 18; i++) {
      // t بالثواني → ~0.5–1.5 دورة/ثانية: وميض طبيعي
      final pulse = (math.sin(t * 1.6 * _sp[i] + _ph[i]) + 1) / 2;
      final scale = 0.5 + pulse * 0.7;
      p.color = color.withValues(alpha: (0.12 + pulse * 0.52).clamp(0.0, 1.0));
      _drawStar(canvas, p,
          Offset(_px[i] * size.width, _py[i] * size.height),
          (_sz[i] + 1) * scale);
    }
  }

  // ── بوكيه — دوائر تتنفس ─────────────────────────────────────────────────
  void _bokeh(Canvas canvas, Size size) {
    for (int i = 0; i < 12; i++) {
      // ~0.2–0.6 دورة/ثانية: تنفس هادئ
      final pulse = (math.sin(t * 0.65 * _sp[i] + _ph[i]) + 1) / 2;
      final c = Offset(_px[i] * size.width, _py[i] * size.height);
      final r = (6.0 + _sz[i] * 4) * (0.65 + pulse * 0.45);
      canvas.drawCircle(c, r, Paint()
          ..color = color.withValues(alpha: 0.03 + pulse * 0.08));
      canvas.drawCircle(c, r, Paint()
        ..color = color.withValues(alpha: 0.07 + pulse * 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6 + pulse * 0.5);
    }
  }

  // ── جسيمات — حركة أوربيتالية لا نهاية لها ───────────────────────────────
  void _particles(Canvas canvas, Size size) {
    final p = Paint();
    for (int i = 0; i < 22; i++) {
      // دوران ثنائي المحور: لا تلف مرئي
      final x = _px[i] * size.width
          + math.sin(t * 0.45 * _sp[i] + _ph[i]) * size.width * 0.13;
      final y = _py[i] * size.height
          + math.cos(t * 0.31 * _sp[i] + _ph[i] + 1.2) * size.height * 0.11;
      final pulse = (math.sin(t * 0.85 * _sp[i] + _ph[i] + 0.5) + 1) / 2;
      p.color = color.withValues(alpha: (0.15 + pulse * 0.45).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), _sz[i] * 0.75 * (0.7 + pulse * 0.5), p);
    }
  }

  // ── بتلات — طوف لا نهائي بدون سقوط ─────────────────────────────────────
  void _petals(Canvas canvas, Size size) {
    for (int i = 0; i < 15; i++) {
      final driftX = math.sin(t * 0.42 * _sp[i] + _ph[i]) * size.width * 0.14;
      final driftY = math.cos(t * 0.28 * _sp[i] + _ph[i] + 0.8)
          * size.height * 0.12;
      final x   = _px[i] * size.width  + driftX;
      final y   = _py[i] * size.height + driftY;
      final rot = _ang[i] + t * 0.38 * _sp[i];
      final pulse = (math.sin(t * 0.55 * _sp[i] + _ph[i] + 1.0) + 1) / 2;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot);
      final path = Path()
        ..moveTo(0, -4)
        ..cubicTo(3, -2, 3.5, 1.5, 0, 4)
        ..cubicTo(-3.5, 1.5, -3, -2, 0, -4);
      canvas.drawPath(path, Paint()
        ..color = color.withValues(alpha: (0.20 + pulse * 0.40).clamp(0.0, 1.0)));
      canvas.restore();
    }
  }

  // ── يراعات — هيام لا نهائي ──────────────────────────────────────────────
  void _fireflies(Canvas canvas, Size size) {
    for (int i = 0; i < 14; i++) {
      final dx    = math.sin(t * 0.55 * _sp[i] + _ph[i]) * 22;
      final dy    = math.cos(t * 0.38 * _sp[i] + _ph[i] + 1) * 14;
      final cx    = _px[i] * size.width  + dx;
      final cy    = _py[i] * size.height + dy;
      final pulse = (math.sin(t * 1.1 * _sp[i] + _ph[i]) + 1) / 2;
      final r     = _sz[i] * 0.85;
      canvas.drawCircle(Offset(cx, cy), r * 4,
          Paint()..color = color.withValues(alpha: pulse * 0.09));
      canvas.drawCircle(Offset(cx, cy), r * 2,
          Paint()..color = color.withValues(alpha: pulse * 0.18));
      canvas.drawCircle(Offset(cx, cy), r,
          Paint()..color = color.withValues(alpha: 0.55 + pulse * 0.45));
    }
  }

  // ── مطر — كل قطرة تلف منفردة، ومحجوبة عند نقطة الالتفاف ────────────────
  void _rain(Canvas canvas, Size size) {
    final p = Paint()..strokeWidth = 0.75;
    for (int i = 0; i < 28; i++) {
      // كل قطرة بسرعة مختلفة → التفافها في أوقات مختلفة (غير مرئي)
      final fall = ((t * _sp[i] * 0.22 + _ph[i] / (math.pi * 2)) % 1.0);
      final x    = _px[i] * size.width;
      final y    = fall * (size.height + 18) - 9;
      final len  = 7.0 + _sz[i] * 2.5;
      // تلاشٍ عند بداية ونهاية الرحلة → لا قطع مرئي
      final fade = math.sin(fall * math.pi).clamp(0.0, 1.0);
      p.color = color.withValues(alpha: (fade * 0.32).clamp(0.0, 1.0));
      canvas.drawLine(Offset(x, y), Offset(x - 1.5, y + len), p);
    }
  }

  // ── ثلج — كل ندفة تلف منفردة ────────────────────────────────────────────
  void _snow(Canvas canvas, Size size) {
    final p = Paint();
    for (int i = 0; i < 20; i++) {
      final drift = math.sin(t * 0.55 * _sp[i] + _ph[i]) * 10;
      final fall  = ((t * _sp[i] * 0.08 + _ph[i] / (math.pi * 2)) % 1.0);
      final x     = _px[i] * size.width + drift;
      final y     = fall * (size.height + 10) - 5;
      final fade  = math.sin(fall * math.pi).clamp(0.0, 1.0);
      p.color = color.withValues(alpha: (fade * 0.65).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), _sz[i] * 0.7, p);
    }
  }

  // ── موجات — جيوب متواصلة طبيعياً ───────────────────────────────────────
  void _waves(Canvas canvas, Size size) {
    for (int w = 0; w < 3; w++) {
      final baseY = size.height * (0.28 + w * 0.24);
      final path  = Path()..moveTo(0, baseY);
      for (double x = 0; x <= size.width; x += 2) {
        final y = baseY
            + math.sin((x / size.width * math.pi * 3.5) + t * 0.9 + w * 1.3) * 11;
        path.lineTo(x, y);
      }
      canvas.drawPath(path, Paint()
        ..color = color.withValues(alpha: 0.10 + w * 0.05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5);
    }
  }

  // ── حبر — قطرات تتسع كدوائر ماء، كل واحدة تلف وحدها ───────────────────
  void _ink(Canvas canvas, Size size) {
    for (int i = 0; i < 12; i++) {
      final phase  = ((t * _sp[i] * 0.14 + _ph[i] / (math.pi * 2)) % 1.0);
      final fade   = (1.0 - phase).clamp(0.0, 1.0);
      final maxR   = 6.0 + _sz[i] * 6;
      final r      = phase * maxR;
      final cx     = _px[i] * size.width;
      final cy     = _py[i] * size.height;
      canvas.drawCircle(Offset(cx, cy), r, Paint()
        ..color = color.withValues(alpha: (fade * 0.28).clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0 + fade * 1.8);
      if (phase < 0.22) {
        final coreFade = (1 - phase / 0.22).clamp(0.0, 1.0);
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
      final pt = Offset(c.dx + math.cos(a) * r, c.dy + math.sin(a) * r);
      if (i == 0) path.moveTo(pt.dx, pt.dy); else path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }
}
