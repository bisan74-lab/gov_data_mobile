import 'package:flutter_test/flutter_test.dart';
import 'package:golf_windy/core/sensors/heading_math.dart';

/// 휴대폰을 **수평으로 눕힌** 상태의 가속도(중력만, 화면이 하늘을 봄).
/// Android 가속도계는 이때 +z에 중력가속도를 그대로 싣는다.
const flat = (x: 0.0, y: 0.0, z: 9.81);

/// 한반도 지자기의 대략적인 크기 — 수평 성분 약 30µT(북쪽), 연직 성분 약
/// 40µT(**아래쪽**, 복각 50도 남짓). 기기 좌표계에서 아래쪽은 -z다.
const _h = 30.0; // 수평(북) 성분
const _v = -40.0; // 연직 성분(아래 → 기기 -z)

void main() {
  group('magneticAzimuthDeg', () {
    test('수평으로 눕히고 위쪽이 북을 보면 0도', () {
      // 기기 +y(윗변)가 북 → 자기장의 수평 성분이 +y에 실린다.
      final az = magneticAzimuthDeg(flat, (x: 0.0, y: _h, z: _v));
      expect(az, closeTo(0, 0.01));
    });

    test('수평으로 눕히고 위쪽이 동을 보면 90도', () {
      // 위쪽이 동을 보면 북은 기기의 -x 방향이 된다.
      final az = magneticAzimuthDeg(flat, (x: -_h, y: 0.0, z: _v));
      expect(az, closeTo(90, 0.01));
    });

    test('수평으로 눕히고 위쪽이 남을 보면 180도', () {
      final az = magneticAzimuthDeg(flat, (x: 0.0, y: -_h, z: _v));
      expect(az, closeTo(180, 0.01));
    });

    test('수평으로 눕히고 위쪽이 서를 보면 270도', () {
      final az = magneticAzimuthDeg(flat, (x: _h, y: 0.0, z: _v));
      expect(az, closeTo(270, 0.01));
    });

    test('기울여 들어도 방위는 유지된다(수평 성분만 보므로)', () {
      // 북을 보며 위쪽을 30도 들어 올린 자세 — 두 벡터를 x축 둘레로 함께
      // 회전시키면 방위각은 변하지 않아야 한다.
      const cos30 = 0.8660254037844387;
      const sin30 = 0.5;
      final a = (x: 0.0, y: -9.81 * sin30, z: 9.81 * cos30);
      final m = (
        x: 0.0,
        y: _h * cos30 - _v * sin30,
        z: _h * sin30 + _v * cos30,
      );
      expect(magneticAzimuthDeg(a, m), closeTo(0, 0.01));
    });

    test('지자기가 중력과 나란하면(자극 부근) null', () {
      expect(magneticAzimuthDeg(flat, (x: 0.0, y: 0.0, z: -50.0)), isNull);
    });
  });

  group('tiltFromFlatDeg', () {
    test('눕히면 0도', () => expect(tiltFromFlatDeg(flat), closeTo(0, 0.01)));

    test('세워 들면 90도', () {
      expect(tiltFromFlatDeg((x: 0.0, y: 9.81, z: 0.0)), closeTo(90, 0.01));
    });
  });

  group('magneticDeclinationDeg', () {
    // 근사식을 맞춘 기준점 세 곳은 WMM 값과 0.1도 안쪽으로 맞아야 한다.
    test('서울', () {
      expect(magneticDeclinationDeg(37.57, 126.98), closeTo(-8.97, 0.1));
    });
    test('인천', () {
      expect(magneticDeclinationDeg(37.46, 126.71), closeTo(-8.91, 0.1));
    });
    test('부산', () {
      expect(magneticDeclinationDeg(35.18, 129.08), closeTo(-8.41, 0.1));
    });

    test('한반도 안에서는 늘 서편(음수) 7~10도 범위', () {
      for (final lat in [33.2, 35.0, 37.0, 38.5]) {
        for (final lon in [126.0, 127.5, 129.5]) {
          final d = magneticDeclinationDeg(lat, lon);
          expect(d, lessThan(-7.0), reason: '$lat,$lon');
          expect(d, greaterThan(-10.0), reason: '$lat,$lon');
        }
      }
    });

    test('한반도 밖 좌표에서도 값이 튀지 않게 제한된다', () {
      expect(magneticDeclinationDeg(80, 100), inInclusiveRange(-11.0, -5.0));
      expect(magneticDeclinationDeg(-40, 170), inInclusiveRange(-11.0, -5.0));
    });
  });

  group('smoothAngleDeg', () {
    test('첫 값은 그대로 통과', () {
      expect(smoothAngleDeg(null, 137, 0.2), closeTo(137, 0.01));
    });

    test('359도에서 1도로 넘어갈 때 반대편으로 돌지 않는다', () {
      // 단순 평균이면 180이 나온다 — 바늘이 한 바퀴 휙 도는 그 버그.
      final r = smoothAngleDeg(359, 1, 0.5);
      expect(r, anyOf(closeTo(0, 0.01), closeTo(360, 0.01)));
    });

    test('alpha만큼만 새 값 쪽으로 움직인다', () {
      expect(smoothAngleDeg(0, 90, 0.5), closeTo(45, 0.01));
      expect(smoothAngleDeg(0, 90, 0.0), closeTo(0, 0.01));
    });

    test('결과는 항상 0~360', () {
      for (final prev in [0.0, 90.0, 200.0, 359.0]) {
        for (final next in [-30.0, 5.0, 400.0]) {
          final r = smoothAngleDeg(prev, next, 0.3);
          expect(r, inInclusiveRange(0, 360));
        }
      }
    });
  });

  group('smoothVec3', () {
    test('첫 값은 그대로', () {
      const v = (x: 1.0, y: 2.0, z: 3.0);
      expect(smoothVec3(null, v, 0.3), v);
    });

    test('성분마다 섞인다', () {
      final r = smoothVec3(
        (x: 0.0, y: 0.0, z: 0.0),
        (x: 10.0, y: 20.0, z: 30.0),
        0.5,
      );
      expect(r.x, closeTo(5, 0.01));
      expect(r.y, closeTo(10, 0.01));
      expect(r.z, closeTo(15, 0.01));
    });
  });
}
