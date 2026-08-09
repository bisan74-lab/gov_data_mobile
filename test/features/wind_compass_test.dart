import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golf_windy/features/compass/presentation/widgets/compass_rose.dart';
import 'package:golf_windy/features/compass/presentation/widgets/wind_compass_button.dart';
import 'package:golf_windy/features/compass/presentation/wind_compass_screen.dart';
import 'package:golf_windy/features/home/presentation/home_screen.dart';

import '../widget_test.dart';

void main() {
  group('screenRotationRad — 기기를 어느 쪽으로 돌려도 방위가 실제 방위를 가리킨다', () {
    /// 회전각을 실제 화면 좌표로 옮겨 본다(`Transform.rotate`와 같은 계산:
    /// 화면 위쪽이 0도이고 시계 방향으로 증가).
    Offset pointAt(double bearing, double heading, {double r = 50}) {
      final a = screenRotationRad(bearing, heading);
      return Offset(100 + r * math.sin(a), 100 - r * math.cos(a));
    }

    test('북을 보고 있으면 북이 화면 위, 동이 오른쪽', () {
      final north = pointAt(0, 0);
      expect(north.dx, closeTo(100, 0.01));
      expect(north.dy, closeTo(50, 0.01)); // 화면 위쪽(y가 작다)

      final east = pointAt(90, 0);
      expect(east.dx, closeTo(150, 0.01));
      expect(east.dy, closeTo(100, 0.01));
    });

    test('기기를 동쪽으로 돌리면 북 표시가 화면 왼쪽으로 간다', () {
      // 기기가 동(90도)을 보면, 북은 내 왼쪽에 있다.
      final north = pointAt(0, 90);
      expect(north.dx, closeTo(50, 0.01)); // 왼쪽
      expect(north.dy, closeTo(100, 0.01));
    });

    test('기기를 남쪽으로 돌리면 북 표시가 화면 아래로 간다', () {
      final north = pointAt(0, 180);
      expect(north.dx, closeTo(100, 0.01));
      expect(north.dy, closeTo(150, 0.01)); // 아래
    });

    test('네 방위는 어떤 각도에서도 서로 90도씩 벌어져 있다', () {
      const center = Offset(100, 100);
      for (final heading in [0.0, 37.0, 123.5, 271.0, 359.9]) {
        final pts = [
          for (final b in [0.0, 90.0, 180.0, 270.0]) pointAt(b, heading),
        ];
        for (var i = 0; i < 4; i++) {
          final a = pts[i] - center;
          final b = pts[(i + 1) % 4] - center;
          // 이웃한 두 방위의 내적은 직각이므로 0이어야 한다.
          expect(
            a.dx * b.dx + a.dy * b.dy,
            closeTo(0, 0.01),
            reason: 'heading=$heading에서 방위 간격이 어긋난다',
          );
        }
      }
    });

    test('방위와 기기 방향이 같으면 화면 맨 위(기기가 향한 쪽)에 온다', () {
      for (final h in [0.0, 45.0, 200.0, 330.0]) {
        final p = pointAt(h, h);
        expect(p.dx, closeTo(100, 0.01));
        expect(p.dy, closeTo(50, 0.01));
      }
    });

    test('원판 회전각은 "북이 놓이는 자리"와 같다', () {
      // 원판을 통째로 돌릴 때 쓰는 값이 방위 계산과 어긋나면, 화살표만
      // 맞고 N 글자는 딴 데를 가리킨다.
      for (final h in [0.0, 73.0, 190.0, 315.0]) {
        expect(screenRotationRad(0, h), closeTo(-h * math.pi / 180, 1e-9));
      }
    });
  });

  testWidgets('나침반 원판과 바람 화살표가 같은 기준으로 함께 돈다', (tester) async {
    // 원판(CompassRose)과 화살표(WindArrowPainter)는 각각 Transform.rotate로
    // 도는데, 두 각도가 같은 heading에서 나와야 화살표가 실제 풍향을
    // 가리킨다. 위젯을 직접 띄워 두 그림이 다 올라오는지 확인한다.
    const heading = 40.0;
    const windFrom = 130.0; // 남동풍
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox.square(
            dimension: 300,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Transform.rotate(
                  angle: screenRotationRad(0, heading),
                  child: const CompassRose(),
                ),
                Transform.rotate(
                  angle: screenRotationRad(windFrom, heading),
                  child: CustomPaint(
                    painter: WindArrowPainter(
                      color: const Color(0xFF29ABE2),
                      outline: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CompassRose), findsOneWidget);
    expect(tester.takeException(), isNull);

    // 풍향(130도)에서 기기 방향(40도)을 뺀 90도 — 화살표는 화면 오른쪽에서
    // 가운데를 향해야 한다.
    expect(
      screenRotationRad(windFrom, heading),
      closeTo(90 * math.pi / 180, 1e-9),
    );
  });

  testWidgets('홈 라운딩 지수 카드 위 오른쪽에 바람나침판 버튼이 있다', (tester) async {
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    final button = find.byKey(windCompassButtonKey);
    expect(button, findsOneWidget);
    // 아이콘만 두면 무슨 버튼인지 모른다는 제보를 지도 마커에서 이미 받았다 —
    // 여기도 글자를 함께 둔다.
    expect(
      find.descendant(of: button, matching: find.text('바람나침판')),
      findsOneWidget,
    );

    // 라운딩 지수 카드 **위쪽**에, 그리고 **오른쪽**에 붙어 있어야 한다.
    final index = find.text('라운딩 지수');
    expect(index, findsOneWidget);
    final buttonRect = tester.getRect(button);
    final indexRect = tester.getRect(index);
    expect(
      buttonRect.bottom,
      lessThanOrEqualTo(indexRect.top),
      reason: '버튼이 라운딩 지수 카드 위가 아니다',
    );

    final screenWidth = tester.getSize(find.byType(MaterialApp)).width;
    expect(
      buttonRect.center.dx,
      greaterThan(screenWidth / 2),
      reason: '버튼이 오른쪽 빈 공간에 있지 않다',
    );
  });

  testWidgets('버튼을 누르면 바람나침판 화면이 열리고 설명 문구가 보인다', (tester) async {
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(windCompassButtonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // 화면 전환

    expect(find.byType(WindCompassScreen), findsOneWidget);
    expect(find.text('바람나침판'), findsWidgets); // AppBar 제목

    // 설명 문구는 **어떤 상태에서도** 하단에 있어야 한다. 테스트 환경에는
    // 위치 서비스가 없어 이 시점은 아직 "위치 확인 중"이다.
    expect(find.text('현재 위치를 확인하는 중…'), findsOneWidget);
    expect(find.text(windCompassCaption), findsOneWidget);

    // 위치를 못 잡아도 화면이 죽지 않는다.
    expect(tester.takeException(), isNull);

    // 위치 조회 시간 제한·센서 대기 타이머를 흘려 보낸 뒤 나간다
    // (남은 타이머가 있으면 테스트 프레임워크가 실패로 잡는다).
    await tester.pump(const Duration(seconds: 16));

    // 화면을 나가며 센서 구독·타이머가 정리되는지도 함께 본다.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(WindCompassScreen), findsNothing);
  });

  testWidgets('위치 응답이 없으면 무한 대기하지 않고 다시 시도 안내로 넘어간다', (tester) async {
    // 위치 서비스가 응답 없이 멈춰 있으면(실내 첫 측위 등) 시간 제한이
    // 없을 때 "확인하는 중…"에서 영영 안 벗어난다. 테스트 환경이 바로 그
    // 상태라, 제한을 걸지 않으면 이 테스트가 실패한다.
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(windCompassButtonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('현재 위치를 확인하는 중…'), findsOneWidget);

    await tester.pump(const Duration(seconds: 16)); // 제한 시간 경과
    await tester.pump();

    expect(find.text('현재 위치를 확인하는 중…'), findsNothing);
    expect(find.text('현재 위치를 확인할 수 없습니다.'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    // 안내 화면에서도 설명 문구는 그대로 보인다.
    expect(find.text(windCompassCaption), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
  });
}
