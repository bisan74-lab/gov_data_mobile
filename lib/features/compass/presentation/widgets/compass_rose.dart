import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 전통 나침반 원판(compass rose)과 바람 화살표.
///
/// **왜 PNG가 아니라 벡터로 그리는가**: 사용자가 준 참고 이미지(흑백 선화
/// 나침반 + 하늘색 화살표)를 그대로 재현하되 코드로 그린다.
/// - 원판은 화면 크기에 따라 지름이 크게 달라지는데(작은 폰 ~300px,
///   큰 폰 ~380px), 래스터는 확대하면 눈금 선이 뭉개진다.
/// - **버튼 아이콘용 28px 축소판**이 특히 문제다 — 원본의 가는 눈금 링과
///   NE/NW 글자는 그 크기에서 그냥 회색 뭉치가 된다. 그래서 아이콘은
///   [CompassRoseDetail.mini]로 요소를 덜어 낸 판을 따로 그린다.
/// - 밝은/어두운 테마에서 선 색이 뒤집혀야 하는데, 흑백 PNG 한 장으로는
///   어두운 테마에서 검은 선이 배경에 묻힌다.
enum CompassRoseDetail {
  /// 나침반 화면용 — 바깥 방사선·눈금 링·NE/NW/SE/SW까지 전부 그린다.
  full,

  /// 버튼 아이콘용 축소판 — 8방위 별과 바깥 원, N 표시만 남긴다.
  mini,
}

/// 나침반 원판. **원판째 회전시켜 쓴다**(`Transform.rotate`) — 참고 이미지의
/// 짜임새(별·눈금·글자가 한 벌로 맞물린 구도)를 그대로 살리려면 요소를 따로
/// 돌리면 안 된다. 그래서 남쪽을 볼 때 S 글자가 뒤집히는데, 이는 실제 자침
/// 나침반의 카드가 도는 방식과 같다. 방위를 글자로 읽어야 할 때를 위해
/// 화면 아래에 한글 풍향 표시를 따로 둔다.
class CompassRose extends StatelessWidget {
  const CompassRose({
    super.key,
    this.detail = CompassRoseDetail.full,
    this.color,
  });

  final CompassRoseDetail detail;

  /// 선·짙은 면의 색. 생략하면 테마의 `onSurface`.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: CompassRosePainter(
        ink: color ?? scheme.onSurface,
        face: scheme.surface,
        detail: detail,
      ),
    );
  }
}

/// 나침반 원판을 그리는 페인터. 좌표는 전부 반지름 `r`에 대한 비율이라
/// 어떤 크기에서도 같은 비례로 그려진다.
class CompassRosePainter extends CustomPainter {
  CompassRosePainter({
    required this.ink,
    required this.face,
    this.detail = CompassRoseDetail.full,
  });

  /// 선과 짙은 면의 색(밝은 테마에서 검정, 어두운 테마에서 흰색).
  final Color ink;

  /// 밝은 면의 색 — 별의 반쪽을 이 색으로 채워 참고 이미지의 명암 대비를 만든다.
  final Color face;

  final CompassRoseDetail detail;

  bool get _mini => detail == CompassRoseDetail.mini;

  /// 방위 [bearing](위쪽이 0도, 시계 방향)에서 반지름 [radius]인 점.
  static Offset _at(Offset c, double bearing, double radius) {
    final a = bearing * math.pi / 180;
    return Offset(c.dx + radius * math.sin(a), c.dy - radius * math.cos(a));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2;

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..color = ink
      ..strokeWidth = math.max(0.7, r * 0.004);
    final fillInk = Paint()..color = ink;
    final fillFace = Paint()..color = face;

    if (_mini) {
      // 축소판: 바깥 원 + 8방위 별 + N 삼각 표시만.
      canvas.drawCircle(c, r * 0.88, line);
      _drawStar(canvas, c, r, fillInk, fillFace, line, mini: true);
      _drawCenterHub(canvas, c, r, fillInk, fillFace);
      // 북쪽을 알리는 작은 삼각형(글자는 이 크기에서 안 읽힌다).
      final tri = Path()
        ..moveTo(c.dx, c.dy - r)
        ..lineTo(c.dx - r * 0.13, c.dy - r * 0.82)
        ..lineTo(c.dx + r * 0.13, c.dy - r * 0.82)
        ..close();
      canvas.drawPath(tri, fillInk);
      return;
    }

    _drawSpikes(canvas, c, r, fillInk);
    // 겹친 두 원 — 참고 이미지의 이중 테두리.
    canvas.drawCircle(c, r * 0.645, line);
    canvas.drawCircle(c, r * 0.610, line);
    _drawTickRing(canvas, c, r, line, fillInk);
    _drawStar(canvas, c, r, fillInk, fillFace, line, mini: false);
    _drawCenterHub(canvas, c, r, fillInk, fillFace);
    _drawCardinalLetters(canvas, c, r);
    _drawOrdinalLetters(canvas, c, r);
  }

  /// 바깥으로 뻗은 가는 방사선. 45도마다 길고, 그 사이는 짧다.
  void _drawSpikes(Canvas canvas, Offset c, double r, Paint fillInk) {
    for (var i = 0; i < 32; i++) {
      final b = i * 11.25;
      final major = b % 45 == 0;
      final inner = r * (major ? 0.66 : 0.68);
      final outer = r * (major ? 0.90 : 0.76);
      final halfW = r * (major ? 0.022 : 0.010);
      final path = Path()
        ..moveTo(_at(c, b, outer).dx, _at(c, b, outer).dy)
        ..lineTo(
          _at(c, b - 90, halfW).dx + (_at(c, b, inner).dx - c.dx),
          _at(c, b - 90, halfW).dy + (_at(c, b, inner).dy - c.dy),
        )
        ..lineTo(
          _at(c, b + 90, halfW).dx + (_at(c, b, inner).dx - c.dx),
          _at(c, b + 90, halfW).dy + (_at(c, b, inner).dy - c.dy),
        )
        ..close();
      canvas.drawPath(path, fillInk);
    }
  }

  /// 안쪽의 눈금 링(참고 이미지의 사다리꼴 눈금 띠).
  void _drawTickRing(
    Canvas canvas,
    Offset c,
    double r,
    Paint line,
    Paint fill,
  ) {
    const outerF = 0.500;
    const innerF = 0.415;
    canvas.drawCircle(c, r * outerF, line);
    canvas.drawCircle(c, r * innerF, line);
    for (var i = 0; i < 72; i++) {
      final b = i * 5.0;
      canvas.drawLine(_at(c, b, r * innerF), _at(c, b, r * outerF), line);
      // 5칸마다 눈금을 채워 굵게 — 참고 이미지의 리듬을 낸다.
      if (i % 6 == 0) {
        final p = Path()
          ..moveTo(_at(c, b, r * innerF).dx, _at(c, b, r * innerF).dy)
          ..lineTo(
            _at(c, b + 2.5, r * innerF).dx,
            _at(c, b + 2.5, r * innerF).dy,
          )
          ..lineTo(
            _at(c, b + 2.5, r * outerF).dx,
            _at(c, b + 2.5, r * outerF).dy,
          )
          ..lineTo(_at(c, b, r * outerF).dx, _at(c, b, r * outerF).dy)
          ..close();
        canvas.drawPath(p, fill);
      }
    }
  }

  /// 8방위 별. 각 갈래를 가운데 선으로 갈라 **한쪽은 짙게, 한쪽은 밝게**
  /// 칠해 참고 이미지의 입체감(바람개비 명암)을 낸다.
  void _drawStar(
    Canvas canvas,
    Offset c,
    double r,
    Paint fillInk,
    Paint fillFace,
    Paint line, {
    required bool mini,
  }) {
    void point(double bearing, double tipF, double halfWF) {
      final tip = _at(c, bearing, r * tipF);
      final left = _at(c, bearing - 90, r * halfWF);
      final right = _at(c, bearing + 90, r * halfWF);
      // 시계 반대쪽 반은 짙게, 시계 쪽 반은 밝게.
      final dark = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(left.dx, left.dy)
        ..lineTo(tip.dx, tip.dy)
        ..close();
      final light = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(right.dx, right.dy)
        ..lineTo(tip.dx, tip.dy)
        ..close();
      canvas.drawPath(dark, fillInk);
      canvas.drawPath(light, fillFace);
      canvas.drawPath(light, line);
    }

    // 대각(NE/SE/SW/NW)을 먼저 그려 주축이 위에 오게 한다.
    for (final b in [45.0, 135.0, 225.0, 315.0]) {
      point(b, mini ? 0.52 : 0.46, mini ? 0.085 : 0.055);
    }
    for (final b in [0.0, 90.0, 180.0, 270.0]) {
      point(b, mini ? 0.86 : 0.82, mini ? 0.10 : 0.062);
    }
  }

  void _drawCenterHub(
    Canvas canvas,
    Offset c,
    double r,
    Paint fillInk,
    Paint fillFace,
  ) {
    canvas.drawCircle(c, r * (_mini ? 0.15 : 0.085), fillInk);
    canvas.drawCircle(c, r * (_mini ? 0.06 : 0.032), fillFace);
  }

  /// N·E·S·W — 원 바깥에 세리프체로. 참고 이미지와 같은 자리.
  void _drawCardinalLetters(Canvas canvas, Offset c, double r) {
    const labels = <(double, String)>[
      (0, 'N'),
      (90, 'E'),
      (180, 'S'),
      (270, 'W'),
    ];
    for (final (bearing, text) in labels) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: ink,
            fontSize: r * 0.15,
            fontFamily: 'serif',
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final p = _at(c, bearing, r * 0.955);
      tp.paint(canvas, Offset(p.dx - tp.width / 2, p.dy - tp.height / 2));
    }
  }

  /// NE·NW·SE·SW — 링 안쪽에 작게, 각 방향을 따라 눕혀서.
  void _drawOrdinalLetters(Canvas canvas, Offset c, double r) {
    const labels = <(double, String)>[
      (45, 'NE'),
      (135, 'SE'),
      (225, 'SW'),
      (315, 'NW'),
    ];
    for (final (bearing, text) in labels) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: ink,
            fontSize: r * 0.062,
            fontFamily: 'serif',
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final p = _at(c, bearing, r * 0.555);
      canvas.save();
      canvas.translate(p.dx, p.dy);
      // 글자 아랫변이 중심을 향하도록 눕힌다(참고 이미지와 같은 배치).
      canvas.rotate((bearing + 180) * math.pi / 180);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(CompassRosePainter old) =>
      old.ink != ink || old.face != face || old.detail != detail;
}

/// 바람 화살표 — 참고 이미지의 **하늘색 굵은 화살표**를 재현한다.
///
/// 12시 방향(위)에서 **가운데를 향해** 꽂히는 모양으로 그린다. 지리 방위에
/// 맞추는 회전은 바깥에서 `Transform.rotate`로 준다.
///
/// 나침반 원판이 선이 많아 어수선하므로 **흰 테두리를 둘러** 어디에 겹쳐도
/// 화살표가 또렷하게 떠 보이게 한다.
class WindArrowPainter extends CustomPainter {
  WindArrowPainter({required this.color, required this.outline});

  final Color color;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2;

    // 바깥(꼬리) → 안쪽(촉). y가 작을수록 위쪽이다.
    final tailY = c.dy - r * 0.94;
    final headBaseY = c.dy - r * 0.46;
    final tipY = c.dy - r * 0.20;
    final headHalf = r * 0.125;
    final tailHalf = r * 0.048;

    final path = Path()
      ..moveTo(c.dx, tipY)
      ..lineTo(c.dx + headHalf, headBaseY)
      ..lineTo(c.dx + tailHalf, headBaseY)
      ..lineTo(c.dx + tailHalf, tailY)
      ..lineTo(c.dx - tailHalf, tailY)
      ..lineTo(c.dx - tailHalf, headBaseY)
      ..lineTo(c.dx - headHalf, headBaseY)
      ..close();

    // 참고 이미지처럼 촉 쪽이 밝고 꼬리로 갈수록 진해지는 결.
    final rect = Rect.fromLTRB(c.dx - headHalf, tipY, c.dx + headHalf, tailY);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.95),
          Color.lerp(color, Colors.white, 0.35)!,
        ],
      ).createShader(rect);

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2, r * 0.018)
        ..strokeJoin = StrokeJoin.round
        ..color = outline,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(WindArrowPainter old) =>
      old.color != color || old.outline != outline;
}
