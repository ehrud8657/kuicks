import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 화면 위에서 운석이 쏟아지고, 픽셀 티라노들이 맞아서 빙글빙글 날아가는 짧은 연출(약 6.6초).
/// 화면 어디든 누르면 바로 끝난다.
class MeteorShower extends StatefulWidget {
  const MeteorShower({super.key, required this.onDone});

  final VoidCallback onDone;

  static const duration = Duration(milliseconds: 6600);

  static OverlayEntry? _entry;

  /// 맨 위 오버레이에 띄운다. 이미 떠 있으면 무시한다.
  static void show(BuildContext context) {
    if (_entry != null) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => MeteorShower(
        onDone: () {
          entry.remove();
          _entry = null;
        },
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }

  @override
  State<MeteorShower> createState() => _MeteorShowerState();
}

class _MeteorShowerState extends State<MeteorShower>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: MeteorShower.duration,
  )
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) _finish();
    })
    ..forward();

  _Scene? scene;
  bool done = false;

  void _finish() {
    if (done) return;
    done = true;
    widget.onDone();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _finish,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              if (scene?.size != size) scene = _Scene(size, math.Random());
              return AnimatedBuilder(
                animation: controller,
                builder: (context, _) => CustomPaint(
                  size: size,
                  painter: _ShowerPainter(
                    scene!,
                    controller.value *
                        MeteorShower.duration.inMilliseconds /
                        1000,
                  ),
                ),
              );
            },
          ),
        ),
      );
}

/// 20칸 너비 픽셀 티라노. X 몸, B 배, O 눈.
abstract final class _Sprite {
  static const width = 20;
  static const height = 19;

  static const body = [
    '...........XXXXXXX..',
    '..........XXOXXXXXX.',
    '..........XXXXXXXXX.',
    '..........XXXXXXXXX.',
    '..........XXXXX.....',
    '..........XXXXXXX...',
    'X........XXXXX......',
    'X.......XXBBXX......',
    'XX.....XXBBBXXXX....',
    'XXX...XXXBBBXX.X....',
    'XXXXXXXXXBBBXX......',
    '.XXXXXXXXBBBXX......',
    '..XXXXXXXXBBXX......',
    '...XXXXXXXXXX.......',
    '....XXXXXXXX........',
  ];

  // 걷는 다리 두 가지 모양
  static const legsA = [
    '.....XXX..XX........',
    '.....XX....X........',
    '.....X.....XX.......',
    '.....XX.............',
  ];
  static const legsB = [
    '.....XX...XXX.......',
    '.....X....XX........',
    '....XX.....X........',
    '...........XX.......',
  ];
}

class _Rex {
  _Rex({
    required this.baseX,
    required this.phase,
    required this.color,
    required this.hitAt,
    required this.vx,
    required this.vy,
    required this.spin,
    required this.facingLeft,
  });

  final double baseX;
  final double phase;
  final Color color;
  final double hitAt;
  final double vx;
  final double vy;
  final double spin;
  final bool facingLeft;

  /// 맞기 전에는 제자리에서 조금씩 왔다 갔다 한다.
  double xAt(double t) => baseX + 14 * math.sin(t * 2.2 + phase);
}

class _Meteor {
  _Meteor(this.start, this.end, this.launch, this.fall, this.size, this.label);

  final Offset start;
  final Offset end;
  final double launch;
  final double fall;
  final double size;
  final String label;

  double get impact => launch + fall;
}

class _Particle {
  _Particle(this.dir, this.speed, this.color, this.size);

  final Offset dir;
  final double speed;
  final Color color;
  final double size;
}

const _fire = [
  Color(0xFFFFE27A),
  Color(0xFFFFB347),
  Color(0xFFFF7A1A),
  Color(0xFFE0301E),
  Color(0xFF6B4A33),
];

const _booms = ['콰광!', '쾅!', '콰과광!', '퍼엉!', '쿵!'];

class _Scene {
  _Scene(this.size, math.Random rnd) {
    final narrow = size.width < 600;
    px = narrow ? 3.0 : 4.0;
    groundTop = size.height - (narrow ? 40 : 56);
    final count = narrow ? 3 : 5;
    final spriteW = _Sprite.width * px;
    final gap = (size.width - count * spriteW) / (count + 1);
    final hitTimes = [for (var i = 0; i < count; i++) 1.1 + i * 0.65]
      ..shuffle(rnd);
    const palette = [
      Color(0xFF4E8B3A),
      Color(0xFF3F7F8C),
      Color(0xFFC0772A),
      Color(0xFF7A5BA8),
      Color(0xFFB31B34),
    ];

    for (var i = 0; i < count; i++) {
      final dir = rnd.nextBool() ? 1.0 : -1.0;
      final rex = _Rex(
        baseX: gap + i * (spriteW + gap),
        phase: rnd.nextDouble() * 6,
        color: palette[i % palette.length],
        hitAt: hitTimes[i],
        vx: dir * (300 + rnd.nextDouble() * 220),
        vy: 900 + rnd.nextDouble() * 400,
        spin: dir * (7 + rnd.nextDouble() * 6),
        facingLeft: rnd.nextBool(),
      );
      rexes.add(rex);
      final end = Offset(
        rex.xAt(rex.hitAt) + spriteW / 2,
        groundTop - _Sprite.height * px * 0.45,
      );
      meteors.add(_meteor(rnd, end, rex.hitAt - 0.75, 0.75, dir, label: true));
    }

    final decoys = narrow ? 6 : 11;
    for (var i = 0; i < decoys; i++) {
      final end = Offset(
        rnd.nextDouble() * size.width,
        groundTop + rnd.nextDouble() * 12,
      );
      meteors.add(
        _meteor(
          rnd,
          end,
          0.25 + rnd.nextDouble() * 4.6,
          0.6 + rnd.nextDouble() * 0.4,
          rnd.nextBool() ? 1 : -1,
          label: rnd.nextBool(),
        ),
      );
    }

    for (var m = 0; m < meteors.length; m++) {
      particles.add([
        for (var k = 0; k < 14; k++)
          _Particle(
            Offset.fromDirection(-math.pi * rnd.nextDouble()),
            140 + rnd.nextDouble() * 280,
            _fire[rnd.nextInt(_fire.length)],
            px * (1 + rnd.nextInt(2)),
          ),
      ]);
    }

    for (var i = 0; i < size.width / (px * 5); i++) {
      pebbles.add(
        Offset(
          rnd.nextDouble() * size.width,
          groundTop + px * 3 + rnd.nextDouble() * (size.height - groundTop),
        ),
      );
    }
  }

  final Size size;
  late final double px;
  late final double groundTop;
  final rexes = <_Rex>[];
  final meteors = <_Meteor>[];
  final particles = <List<_Particle>>[];
  final pebbles = <Offset>[];

  _Meteor _meteor(
    math.Random rnd,
    Offset end,
    double launch,
    double fall,
    double dir, {
    required bool label,
  }) {
    final dx = dir * size.height * (0.35 + rnd.nextDouble() * 0.2);
    return _Meteor(
      Offset(end.dx - dx, -80),
      end,
      launch,
      fall,
      (size.width < 600 ? 5 : 6) + rnd.nextInt(3).toDouble(),
      label ? _booms[rnd.nextInt(_booms.length)] : '',
    );
  }
}

class _ShowerPainter extends CustomPainter {
  _ShowerPainter(this.scene, this.t);

  final _Scene scene;
  final double t;

  static const _gravity = 1600.0;

  double get _total => MeteorShower.duration.inMilliseconds / 1000;

  Offset _snap(Offset o) => Offset(
        (o.dx / scene.px).roundToDouble() * scene.px,
        (o.dy / scene.px).roundToDouble() * scene.px,
      );

  @override
  void paint(Canvas canvas, Size size) {
    final fade = t < 0.3
        ? t / 0.3
        : t > _total - 0.6
            ? ((_total - t) / 0.6).clamp(0.0, 1.0)
            : 1.0;
    final paint = Paint()..isAntiAlias = false;

    // 떨어질 때마다 화면이 흔들리고 주황빛으로 번쩍인다.
    var shake = Offset.zero;
    var flash = 0.0;
    for (final m in scene.meteors) {
      final dt = t - m.impact;
      if (dt >= 0 && dt < 0.35) {
        final amp = 8 * (1 - dt / 0.35);
        shake += Offset(
          math.sin(dt * 95 + m.end.dx) * amp,
          math.cos(dt * 80 + m.end.dx) * amp * 0.6,
        );
      }
      if (dt >= 0 && dt < 0.22) flash = math.max(flash, 1 - dt / 0.22);
    }
    canvas.drawRect(
      Offset.zero & size,
      paint..color = const Color(0xFF0C0814).withValues(alpha: 0.35 * fade),
    );
    if (flash > 0) {
      canvas.drawRect(
        Offset.zero & size,
        paint
          ..color =
              const Color(0xFFFF8C28).withValues(alpha: 0.16 * flash * fade),
      );
    }

    canvas.save();
    canvas.translate(shake.dx, shake.dy);
    _paintGround(canvas, size, paint, fade);
    for (final rex in scene.rexes) {
      _paintRex(canvas, size, rex, paint, fade);
    }
    for (var i = 0; i < scene.meteors.length; i++) {
      _paintMeteor(canvas, scene.meteors[i], paint, fade);
      _paintBurst(canvas, scene.meteors[i], scene.particles[i], paint, fade);
    }
    canvas.restore();
  }

  void _paintGround(Canvas canvas, Size size, Paint paint, double fade) {
    final top = scene.groundTop;
    final px = scene.px;
    canvas.drawRect(
      Rect.fromLTRB(-24, top, size.width + 24, size.height + 24),
      paint..color = const Color(0xFF7A5230).withValues(alpha: fade),
    );
    canvas.drawRect(
      Rect.fromLTRB(-24, top, size.width + 24, top + px * 2),
      paint..color = const Color(0xFF5E9E3F).withValues(alpha: fade),
    );
    paint.color = const Color(0xFF5C3B20).withValues(alpha: fade);
    for (final p in scene.pebbles) {
      canvas.drawRect(Rect.fromLTWH(p.dx, p.dy, px, px), paint);
    }
    // 떨어진 자리에는 움푹 파인 자국이 남는다.
    paint.color = const Color(0xFF3A2414).withValues(alpha: fade);
    for (final m in scene.meteors) {
      if (t < m.impact) continue;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(m.end.dx, top + px),
          width: m.size * px * 2.4,
          height: px * 3,
        ),
        paint,
      );
    }
  }

  void _paintRex(Canvas canvas, Size size, _Rex rex, Paint paint, double fade) {
    final px = scene.px;
    final w = _Sprite.width * px;
    final h = _Sprite.height * px;
    final flying = t >= rex.hitAt;
    Offset center;
    var angle = 0.0;
    if (!flying) {
      center = Offset(rex.xAt(t) + w / 2, scene.groundTop - h / 2);
    } else {
      final dt = t - rex.hitAt;
      center = Offset(
        rex.xAt(rex.hitAt) + w / 2 + rex.vx * dt,
        scene.groundTop - h / 2 - (rex.vy * dt - 0.5 * _gravity * dt * dt),
      );
      angle = rex.spin * dt;
      if (center.dy > size.height + h ||
          center.dx < -w * 2 ||
          center.dx > size.width + w * 2) {
        return;
      }
    }

    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (angle != 0) canvas.rotate(angle);
    if (rex.facingLeft) canvas.scale(-1, 1);
    canvas.translate(-w / 2, -h / 2);
    final walkA = (t * 8).floor().isEven;
    final rows = [
      ..._Sprite.body,
      ...(flying || walkA ? _Sprite.legsA : _Sprite.legsB),
    ];
    final belly = Color.lerp(rex.color, Colors.white, 0.4)!;
    for (var r = 0; r < rows.length; r++) {
      final row = rows[r].padRight(_Sprite.width, '.');
      for (var c = 0; c < _Sprite.width; c++) {
        final cell = row[c];
        if (cell == '.') continue;
        final color = switch (cell) {
          // 맞은 뒤에는 눈이 빨개진다.
          'O' => flying ? const Color(0xFFFF3B3B) : Colors.white,
          'B' => belly,
          _ => rex.color,
        };
        paint.color = color.withValues(alpha: fade);
        canvas.drawRect(Rect.fromLTWH(c * px, r * px, px, px), paint);
      }
    }
    canvas.restore();
  }

  void _paintMeteor(Canvas canvas, _Meteor m, Paint paint, double fade) {
    if (t < m.launch || t > m.impact) return;
    final px = scene.px;
    final p = (t - m.launch) / m.fall;
    Offset at(double q) => Offset.lerp(m.start, m.end, q)!;

    // 불꼬리
    for (var k = 10; k >= 1; k--) {
      final q = p - k * 0.028;
      if (q < 0) continue;
      final s = (m.size - k * 0.45).clamp(1.0, 99.0) * px * 0.8;
      final color = Color.lerp(
        const Color(0xFFFFE27A),
        const Color(0xFFE0301E),
        k / 10,
      )!;
      paint.color = color.withValues(alpha: (1 - k / 11) * 0.85 * fade);
      canvas.drawRect(
        Rect.fromCenter(center: _snap(at(q)), width: s, height: s),
        paint,
      );
    }

    // 돌덩이 머리: 가운데는 어두운 돌, 가장자리는 불
    final head = _snap(at(p));
    final radius = m.size / 2;
    final reach = radius.ceil();
    for (var y = -reach; y <= reach; y++) {
      for (var x = -reach; x <= reach; x++) {
        final d = math.sqrt(x * x + y * y);
        if (d > radius + 0.3) continue;
        final color = d > radius - 1
            ? const Color(0xFFFF7A1A)
            : d > radius - 2
                ? const Color(0xFFFFC04D)
                : const Color(0xFF5A3A26);
        paint.color = color.withValues(alpha: fade);
        canvas.drawRect(
          Rect.fromLTWH(
              head.dx + x * px - px / 2, head.dy + y * px - px / 2, px, px),
          paint,
        );
      }
    }
  }

  void _paintBurst(
    Canvas canvas,
    _Meteor m,
    List<_Particle> parts,
    Paint paint,
    double fade,
  ) {
    final dt = t - m.impact;
    if (dt < 0 || dt > 0.9) return;
    final life = 1 - dt / 0.9;
    for (final part in parts) {
      final pos = m.end + part.dir * part.speed * dt + Offset(0, 900 * dt * dt);
      paint.color = part.color.withValues(alpha: life * fade);
      canvas.drawRect(
        Rect.fromCenter(
            center: _snap(pos), width: part.size, height: part.size),
        paint,
      );
    }

    if (dt < 0.3) {
      canvas.drawCircle(
        m.end,
        10 + dt * 260,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = scene.px * 2
          ..color =
              const Color(0xFFFFE27A).withValues(alpha: (1 - dt / 0.3) * fade),
      );
    }

    if (m.label.isEmpty || dt >= 0.7) return;
    final scale = dt < 0.12 ? 0.6 + dt / 0.12 * 0.6 : 1.2 - (dt - 0.12) * 0.3;
    final fontSize = (scene.px < 4 ? 20.0 : 28.0) * scale;
    final alpha = (dt < 0.5 ? 1.0 : (0.7 - dt) / 0.2) * fade;
    TextPainter layout(TextStyle style) => TextPainter(
          text: TextSpan(text: m.label, style: style),
          textDirection: TextDirection.ltr,
        )..layout();
    final base = TextStyle(
      // 한글 대체 글꼴을 받지 않도록 앱에 넣어 둔 글꼴을 쓴다.
      fontFamily: 'Pretendard',
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
    );
    final stroke = layout(
      base.copyWith(
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = const Color(0xFF2A1208).withValues(alpha: alpha),
      ),
    );
    final fill = layout(
      base.copyWith(color: const Color(0xFFFFD84A).withValues(alpha: alpha)),
    );
    final pos = m.end + Offset(-fill.width / 2, -fill.height - 24 - dt * 40);
    stroke.paint(canvas, pos);
    fill.paint(canvas, pos);
    stroke.dispose();
    fill.dispose();
  }

  @override
  bool shouldRepaint(_ShowerPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.scene != scene;
}
