import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 거대한 운석이 쏟아져 화면을 뒤덮고, 충돌로 화면이 크게 흔들린 뒤
/// 픽셀 공룡들이 빙글빙글 우주로 날아가고, 가운데에 제작 표기가 떠오르는 짧은 연출(약 9초).
/// 화면 어디든 누르면 바로 끝난다.
class MeteorShower extends StatefulWidget {
  const MeteorShower({super.key, required this.onDone});

  final VoidCallback onDone;

  static const duration = Duration(milliseconds: 9000);

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
                builder: (context, _) {
                  final t = controller.value *
                      MeteorShower.duration.inMilliseconds /
                      1000;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(
                          size: size, painter: _ShowerPainter(scene!, t)),
                      _Credit(t: t, narrow: size.width < 600),
                    ],
                  );
                },
              );
            },
          ),
        ),
      );
}

/// 공룡들이 날아가며 마무리될 때 화면 가운데에 떠오르는 제작 표기.
class _Credit extends StatelessWidget {
  const _Credit({required this.t, required this.narrow});

  final double t;
  final bool narrow;

  static const text = 'Development & Design Support — 2026320053 김태호';

  /// 떠오르기 시작하는 시각(초). 마지막 공룡이 날아오른 직후다.
  static const showAt = 4.4;

  @override
  Widget build(BuildContext context) {
    final total = MeteorShower.duration.inMilliseconds / 1000;
    final appear = ((t - showAt) / 0.8).clamp(0.0, 1.0);
    final opacity = math.min(
      Curves.easeOut.transform(appear),
      ((total - t) / 0.6).clamp(0.0, 1.0),
    );
    if (opacity <= 0) return const SizedBox.shrink();
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - Curves.easeOut.transform(appear))),
            // 좁은 화면에서는 줄표 앞에서 줄을 바꾼다.
            child: Text(
              narrow ? text.replaceFirst(' — ', '\n— ') : text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Pretendard',
                color: Colors.white,
                fontSize: narrow ? 17 : 24,
                fontWeight: FontWeight.w700,
                height: 1.5,
                letterSpacing: 0.3,
                decoration: TextDecoration.none,
                shadows: const [
                  Shadow(color: Color(0xCC000000), blurRadius: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 픽셀 공룡 그림. X 몸, B 배, O 눈.
abstract final class _Sprites {
  static const rex = [
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
    '.....XXX..XX........',
    '.....XX....X........',
    '.....X.....XX.......',
    '.....XX.............',
  ];

  static const longNeck = [
    '......................XXX.',
    '.....................XXOXX',
    '.....................XXXX.',
    '....................XXX...',
    '...................XXX....',
    '..................XXX.....',
    '.................XXX......',
    '.........XXXXXXXXXX.......',
    '.......XXXXXXXXXXXXX......',
    'XX...XXXXXBBBBBBXXXXX.....',
    '.XXXXXXXXBBBBBBBBXXXX.....',
    '..XXXXXXXXBBBBBBXXXXX.....',
    '.....XXXXXXXXXXXXXXX......',
    '.....XXX..XXX..XXX........',
    '.....XXX..XXX..XXX........',
    '.....XX....XX...XX........',
  ];
}

class _Meteor {
  _Meteor({
    required this.start,
    required this.end,
    required this.launch,
    required this.fall,
    required this.radius,
    required this.px,
    required this.seed,
  });

  final Offset start;
  final Offset end;
  final double launch;
  final double fall;

  /// 머리 반지름(픽셀 칸 수)
  final double radius;

  /// 칸 하나의 크기
  final double px;
  final double seed;

  double get impact => launch + fall;
}

class _Dino {
  _Dino({
    required this.sprite,
    required this.px,
    required this.launchAt,
    required this.start,
    required this.vx,
    required this.vy,
    required this.spin,
    required this.color,
    required this.flip,
  });

  final List<String> sprite;
  final double px;
  final double launchAt;
  final Offset start;
  final double vx;
  final double vy;
  final double spin;
  final Color color;
  final bool flip;

  static const gravity = 160.0;

  int get rows => sprite.length;
  int get cols => sprite.fold(0, (w, row) => math.max(w, row.length));

  Offset positionAt(double dt) => Offset(
        start.dx + vx * dt,
        start.dy - vy * dt + 0.5 * gravity * dt * dt,
      );
}

class _Particle {
  _Particle(this.dir, this.speed, this.color, this.size);

  final Offset dir;
  final double speed;
  final Color color;
  final double size;
}

class _Star {
  _Star(this.pos, this.phase, this.size);

  final Offset pos;
  final double phase;
  final double size;
}

class _Scene {
  _Scene(this.size, math.Random rnd) {
    final w = size.width;
    final h = size.height;
    final narrow = w < 600;

    // 빗발치는 운석: 모두 오른쪽 위에서 왼쪽 아래로, 화면 아래로 빠져나간다.
    final count = narrow ? 13 : 24;
    final small = narrow ? 5.0 : 6.0;
    for (var i = 0; i < count; i++) {
      final end = Offset(-0.1 * w + rnd.nextDouble() * 1.3 * w, h + 120);
      meteors.add(
        _Meteor(
          start: end + Offset(h * (0.7 + rnd.nextDouble() * 0.2), -(h + 420)),
          end: end,
          launch: rnd.nextDouble() * 1.55,
          fall: 0.55 + rnd.nextDouble() * 0.3,
          radius: 5 + rnd.nextInt(6).toDouble(),
          px: small,
          seed: rnd.nextDouble() * 10,
        ),
      );
    }
    meteors.sort((a, b) => a.radius.compareTo(b.radius));

    // 마지막에 화면 아래 가운데를 때리는 거대한 운석
    final impactPoint = Offset(w / 2, h);
    main = _Meteor(
      start: impactPoint + Offset(h * 0.85, -(h * 1.6 + 300)),
      end: impactPoint,
      launch: impactAt - 1.15,
      fall: 1.15,
      radius: narrow ? 12 : 17,
      px: narrow ? 6 : 7,
      seed: rnd.nextDouble() * 10,
    );

    const debrisColors = [
      Color(0xFFFFE27A),
      Color(0xFFFFB347),
      Color(0xFFFF7A1A),
      Color(0xFFE0301E),
      Color(0xFF5A3A26),
    ];
    for (var i = 0; i < (narrow ? 32 : 52); i++) {
      debris.add(
        _Particle(
          Offset.fromDirection(-math.pi * (0.08 + rnd.nextDouble() * 0.84)),
          500 + rnd.nextDouble() * 900,
          debrisColors[rnd.nextInt(debrisColors.length)],
          small * (1 + rnd.nextInt(3)),
        ),
      );
    }

    for (var i = 0; i < (narrow ? 45 : 90); i++) {
      stars.add(
        _Star(
          Offset(rnd.nextDouble() * w, rnd.nextDouble() * h),
          rnd.nextDouble() * 6,
          1.5 + rnd.nextInt(3).toDouble(),
        ),
      );
    }

    // 충돌 뒤 차례로 날아오르는 공룡들
    const palette = [
      Color(0xFF4E8B3A),
      Color(0xFF9C9A8E),
      Color(0xFF3F7F8C),
      Color(0xFFC0772A),
      Color(0xFF7A5BA8),
      Color(0xFFB31B34),
    ];
    final dinoCount = narrow ? 6 : 10;
    final launches = [
      for (var i = 0; i < dinoCount; i++) impactAt + 0.25 + i * 0.14,
    ]..shuffle(rnd);
    for (var i = 0; i < dinoCount; i++) {
      final startX = w * (0.25 + rnd.nextDouble() * 0.5);
      var dir = startX < w / 2 ? -1.0 : 1.0;
      if (rnd.nextDouble() < 0.25) dir = -dir;
      dinos.add(
        _Dino(
          sprite: rnd.nextInt(3) == 0 ? _Sprites.longNeck : _Sprites.rex,
          px: narrow
              ? 3 + rnd.nextInt(3).toDouble()
              : 4 + rnd.nextInt(5).toDouble(),
          launchAt: launches[i],
          start: Offset(startX, h + 60),
          vx: dir * w * (0.12 + rnd.nextDouble() * 0.4),
          vy: h * (0.85 + rnd.nextDouble() * 0.5),
          spin: (rnd.nextBool() ? 1 : -1) * (3 + rnd.nextDouble() * 7),
          color: palette[i % palette.length],
          flip: rnd.nextBool(),
        ),
      );
    }
  }

  /// 거대한 운석이 떨어지는 순간(초)
  static const impactAt = 2.35;

  final Size size;
  final meteors = <_Meteor>[];
  late final _Meteor main;
  final debris = <_Particle>[];
  final stars = <_Star>[];
  final dinos = <_Dino>[];
}

class _ShowerPainter extends CustomPainter {
  _ShowerPainter(this.scene, this.t);

  final _Scene scene;
  final double t;

  double get _total => MeteorShower.duration.inMilliseconds / 1000;

  static Offset _snap(Offset o, double px) => Offset(
        (o.dx / px).roundToDouble() * px,
        (o.dy / px).roundToDouble() * px,
      );

  static double _cells(double length, double px) =>
      math.max(1, (length / px).roundToDouble()) * px;

  @override
  void paint(Canvas canvas, Size size) {
    final fade = math.min(
      (t / 0.25).clamp(0.0, 1.0),
      ((_total - t) / 0.6).clamp(0.0, 1.0),
    );
    if (fade <= 0) return;
    final layered = fade < 1;
    if (layered) {
      canvas.saveLayer(
        Offset.zero & size,
        Paint()..color = Colors.black.withValues(alpha: fade),
      );
    }

    final paint = Paint()..isAntiAlias = false;
    final sinceImpact = t - _Scene.impactAt;

    // 충돌 직후 화면이 크게 흔들리다 잦아든다.
    var shake = Offset.zero;
    if (sinceImpact >= 0 && sinceImpact < 1.1) {
      final amp = 26 * math.pow(1 - sinceImpact / 1.1, 1.5);
      shake = Offset(
        math.sin(sinceImpact * 72) * amp,
        math.cos(sinceImpact * 57) * amp * 0.7,
      );
    }
    canvas.save();
    canvas.translate(shake.dx, shake.dy);
    final area = (Offset.zero & size).inflate(80);

    // 하늘이 어두워지고, 거대한 운석이 다가올수록 붉게 달아오른다.
    final approach =
        ((t - scene.main.launch) / scene.main.fall).clamp(0.0, 1.0);
    canvas.drawRect(
      area,
      paint
        ..color = const Color(0xFF120A10).withValues(
          alpha: 0.3 + 0.25 * (t / _Scene.impactAt).clamp(0.0, 1.0),
        ),
    );
    if (sinceImpact < 0) {
      canvas.drawRect(
        area,
        paint
          ..color = const Color(0xFFFF6A1A)
              .withValues(alpha: 0.28 * approach * approach),
      );
    }

    // 충돌 뒤에는 우주처럼 캄캄해지고 별이 반짝인다.
    if (sinceImpact > 0.15) {
      final dark = ((sinceImpact - 0.15) / 0.6).clamp(0.0, 1.0);
      canvas.drawRect(
        area,
        paint..color = const Color(0xFF050814).withValues(alpha: 0.82 * dark),
      );
      for (final star in scene.stars) {
        final twinkle = 0.35 + 0.65 * math.pow(math.sin(t * 3 + star.phase), 2);
        paint.color = Colors.white.withValues(alpha: dark * twinkle);
        canvas.drawRect(
          Rect.fromLTWH(star.pos.dx, star.pos.dy, star.size, star.size),
          paint,
        );
      }
    }

    for (final meteor in scene.meteors) {
      _paintMeteor(canvas, meteor, paint);
    }
    _paintMeteor(canvas, scene.main, paint);

    if (sinceImpact >= 0) _paintImpact(canvas, size, paint, sinceImpact);

    for (final dino in scene.dinos) {
      _paintDino(canvas, size, dino, paint);
    }

    // 충돌 순간 하얗게 번쩍였다가 주황빛으로 식는다.
    if (sinceImpact >= 0 && sinceImpact < 0.65) {
      final alpha =
          sinceImpact < 0.12 ? 0.95 : 0.95 * (1 - (sinceImpact - 0.12) / 0.53);
      final color = Color.lerp(
        Colors.white,
        const Color(0xFFFF9A3D),
        (sinceImpact / 0.65).clamp(0.0, 1.0),
      )!;
      canvas.drawRect(
        area,
        paint..color = color.withValues(alpha: alpha.clamp(0.0, 1.0)),
      );
    }

    canvas.restore();
    if (layered) canvas.restore();
  }

  void _paintMeteor(Canvas canvas, _Meteor m, Paint paint) {
    if (t < m.launch || t > m.impact) return;
    final p = (t - m.launch) / m.fall;
    Offset at(double q) => Offset.lerp(m.start, m.end, q)!;
    final path = m.end - m.start;
    final unit = path / path.distance;
    final normal = Offset(-unit.dy, unit.dx);
    final headR = m.radius * m.px;

    // 꼬리: 머리 쪽은 뜨거운 불, 멀어질수록 붉은 불 → 검은 연기
    const segments = 28;
    for (var k = segments; k >= 1; k--) {
      final q = p - k * 0.02;
      if (q < 0) continue;
      final f = k / segments;
      final wobble = math.sin(t * 28 + k * 1.7 + m.seed) * m.px * 1.6 * f;
      final pos = at(q) + normal * wobble;
      final side = _cells(headR * 2 * (1.05 - f * 0.5), m.px);
      final Color color;
      final double alpha;
      if (f < 0.35) {
        color = Color.lerp(
          const Color(0xFFFFF1B0),
          const Color(0xFFFF9A2E),
          f / 0.35,
        )!;
        alpha = 0.95;
      } else if (f < 0.65) {
        color = Color.lerp(
          const Color(0xFFFF9A2E),
          const Color(0xFFD9321C),
          (f - 0.35) / 0.3,
        )!;
        alpha = 0.85;
      } else {
        color = Color.lerp(
          const Color(0xFF6E4A40),
          const Color(0xFF2B2327),
          (f - 0.65) / 0.35,
        )!;
        alpha = 0.05 + 0.7 * (1 - (f - 0.65) / 0.35);
      }
      paint.color = color.withValues(alpha: alpha);
      canvas.drawRect(
        Rect.fromCenter(center: _snap(pos, m.px), width: side, height: side),
        paint,
      );
    }

    final head = _snap(at(p), m.px);
    final glowR = headR * 2.6;
    canvas.drawCircle(
      head,
      glowR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFB45C).withValues(alpha: 0.6),
            const Color(0xFFFF6A1A).withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: head, radius: glowR)),
    );

    // 머리: 진행 방향 쪽 가장자리가 가장 뜨겁고, 뒤쪽은 어두운 돌덩이
    final reach = m.radius.ceil();
    for (var y = -reach; y <= reach; y++) {
      for (var x = -reach; x <= reach; x++) {
        final d = math.sqrt(x * x + y * y);
        if (d > m.radius + 0.3) continue;
        final front = (x * unit.dx + y * unit.dy) / m.radius;
        final Color color;
        if (d > m.radius - 1.2) {
          color = front > 0 ? const Color(0xFFFFF1B0) : const Color(0xFFFF7A1A);
        } else if (d > m.radius - 2.6) {
          color = const Color(0xFFFFB347);
        } else {
          color =
              front > 0.3 ? const Color(0xFFC8551E) : const Color(0xFF4A2E1E);
        }
        paint.color = color;
        canvas.drawRect(
          Rect.fromLTWH(
            head.dx + x * m.px - m.px / 2,
            head.dy + y * m.px - m.px / 2,
            m.px,
            m.px,
          ),
          paint,
        );
      }
    }
  }

  void _paintImpact(Canvas canvas, Size size, Paint paint, double dt) {
    final origin = Offset(size.width / 2, size.height);

    // 충격파 고리 두 겹
    for (final (delay, weight) in const [(0.0, 1.0), (0.14, 0.6)]) {
      final d = dt - delay;
      if (d < 0 || d > 0.9) continue;
      final life = 1 - d / 0.9;
      canvas.drawCircle(
        origin,
        30 + d * size.longestSide * 1.1,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1 + 30 * weight * life
          ..color = const Color(0xFFFFE0A0).withValues(alpha: 0.8 * life),
      );
    }

    if (dt > 1.4) return;
    final life = 1 - dt / 1.4;
    for (final part in scene.debris) {
      final pos =
          origin + part.dir * part.speed * dt + Offset(0, 700 * dt * dt);
      paint.color = part.color.withValues(alpha: life);
      canvas.drawRect(
        Rect.fromCenter(center: pos, width: part.size, height: part.size),
        paint,
      );
    }
  }

  void _paintDino(Canvas canvas, Size size, _Dino dino, Paint paint) {
    final dt = t - dino.launchAt;
    if (dt <= 0) return;
    final w = dino.cols * dino.px;
    final h = dino.rows * dino.px;
    // 앞선 자리에 옅은 잔상을 남겨 휙 날아가는 느낌을 준다.
    for (var k = 4; k >= 0; k--) {
      final g = dt - k * 0.045;
      if (g <= 0) continue;
      final center = dino.positionAt(g);
      if (center.dy < -h * 2 ||
          center.dy > size.height + h * 2 ||
          center.dx < -w * 2 ||
          center.dx > size.width + w * 2) {
        continue;
      }
      _paintSprite(
        canvas,
        dino,
        center,
        angle: dino.spin * g,
        scale: 1 + g * 0.12,
        alpha: k == 0 ? 1.0 : 0.22 * (1 - k / 5),
        paint: paint,
      );
    }
  }

  void _paintSprite(
    Canvas canvas,
    _Dino dino,
    Offset center, {
    required double angle,
    required double scale,
    required double alpha,
    required Paint paint,
  }) {
    final px = dino.px;
    final w = dino.cols * px;
    final h = dino.rows * px;
    final belly = Color.lerp(dino.color, Colors.white, 0.4)!;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.scale(dino.flip ? -scale : scale, scale);
    canvas.translate(-w / 2, -h / 2);
    for (var r = 0; r < dino.rows; r++) {
      final row = dino.sprite[r];
      for (var c = 0; c < row.length; c++) {
        final cell = row[c];
        if (cell == '.') continue;
        final color = switch (cell) {
          'O' => Colors.white,
          'B' => belly,
          _ => dino.color,
        };
        paint.color = color.withValues(alpha: alpha);
        // 돌아갈 때 칸 사이 틈이 보이지 않게 살짝 겹쳐 그린다.
        canvas.drawRect(
            Rect.fromLTWH(c * px, r * px, px + 0.6, px + 0.6), paint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShowerPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.scene != scene;
}
