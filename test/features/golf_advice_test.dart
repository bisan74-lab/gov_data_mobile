import 'package:golf_windy/features/golf/data/golf_courses_data.dart';
import 'package:golf_windy/features/golf/logic/golf_advice.dart';
import 'package:golf_windy/features/golf/presentation/providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('roundingIndex', () {
    test('쾌적한 조건(약풍·무강수·적정기온)이면 최고점에 가깝다', () {
      final idx = roundingIndex(
        tempC: 20,
        windSpeedMs: 2,
        windGustMs: 4,
        precipProbPct: 0,
      );
      expect(idx, greaterThanOrEqualTo(9));
      expect(roundingLabel(idx), '최적');
    });

    test('강풍이면 지수가 크게 떨어진다', () {
      final calm = roundingIndex(
        tempC: 20,
        windSpeedMs: 2,
        windGustMs: 3,
        precipProbPct: 0,
      );
      final windy = roundingIndex(
        tempC: 20,
        windSpeedMs: 14,
        windGustMs: 20,
        precipProbPct: 0,
      );
      expect(windy, lessThan(calm));
    });

    test('높은 강수확률도 지수를 낮춘다', () {
      final dry = roundingIndex(
        tempC: 20,
        windSpeedMs: 3,
        windGustMs: 5,
        precipProbPct: 0,
      );
      final wet = roundingIndex(
        tempC: 20,
        windSpeedMs: 3,
        windGustMs: 5,
        precipProbPct: 90,
      );
      expect(wet, lessThan(dry));
    });

    test('결과는 항상 1~10 범위', () {
      final low = roundingIndex(
        tempC: -5,
        windSpeedMs: 25,
        windGustMs: 35,
        precipProbPct: 100,
      );
      expect(low, inInclusiveRange(1, 10));
    });
  });

  group('outfitAdvice', () {
    test('더울 때는 반팔·자외선 차단을 권한다', () {
      final s = outfitAdvice(tempC: 30, windSpeedMs: 2, precipProbPct: 0);
      expect(s.contains('반팔'), isTrue);
    });

    test('추울 때는 방한을 권한다', () {
      final s = outfitAdvice(tempC: 2, windSpeedMs: 3, precipProbPct: 0);
      expect(s.contains('방한'), isTrue);
    });

    test('강수확률이 높으면 우비/우산을 덧붙인다', () {
      final s = outfitAdvice(tempC: 18, windSpeedMs: 3, precipProbPct: 80);
      expect(s.contains('우비') || s.contains('우산'), isTrue);
    });
  });

  group('golf courses data', () {
    test('시드 목록이 비어있지 않고 좌표가 한반도 bbox 안에 있다', () {
      expect(golfCourses, isNotEmpty);
      for (final c in golfCourses) {
        expect(c.latitude, inInclusiveRange(33.0, 39.0));
        expect(c.longitude, inInclusiveRange(124.0, 132.0));
      }
    });

    test('id는 중복되지 않는다', () {
      final ids = golfCourses.map((c) => c.id).toSet();
      expect(ids.length, golfCourses.length);
    });

    test('golfCourseById로 조회된다', () {
      final first = golfCourses.first;
      expect(golfCourseById(first.id), first);
      expect(golfCourseById('no_such'), isNull);
    });
  });
}
