import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golf_windy/app/theme.dart';
import 'package:golf_windy/features/home/presentation/widgets/home_date_strip.dart';

/// 날짜 띠가 **밝은 테마·어두운 테마 양쪽에서 실제로 읽히는지** 검사한다.
///
/// 이 파일이 생긴 이유: 칩 색이 `Colors.white` 고정이었다. 색이 있는 헤더
/// 위에 놓일 걸 전제한 코드였는데 실제로는 기본 배경 위에 놓여서, **밝은
/// 테마에서 흰 글자·흰 칸이 흰 배경에 묻혀 날짜가 통째로 안 보였다**
/// (2026-08-09 제보). 렌더링은 정상이라 오버플로 검사로는 안 잡힌다 —
/// 색 대비를 직접 재야 잡힌다.
void main() {
  /// 두 색의 상대 명도 대비(1~21). WCAG 기준 본문 글자는 4.5:1 이상,
  /// 큰 글자·굵은 글자는 3:1 이상이면 읽을 수 있다고 본다.
  double contrastRatio(Color a, Color b) {
    double channel(double c) =>
        c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4) as double;
    double luminance(Color c) =>
        0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
    final la = luminance(a);
    final lb = luminance(b);
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  /// 화면에 실제로 그려진 [Text]들의 색과, 그 뒤 칩 배경색을 모아 온다.
  ({List<Color> textColors, List<Color> chipColors}) collect(
    WidgetTester tester,
  ) {
    final texts = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(HomeDateStrip),
            matching: find.byType(Text),
          ),
        )
        .map((t) => t.style!.color!)
        .toList();
    final chips = tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(HomeDateStrip),
            matching: find.byType(Container),
          ),
        )
        .map((c) => (c.decoration! as BoxDecoration).color!)
        .toList();
    return (textColors: texts, chipColors: chips);
  }

  Future<void> pumpStrip(WidgetTester tester, Brightness brightness) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final theme = brightness == Brightness.light
        ? buildLightTheme()
        : buildDarkTheme();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: HomeDateStrip(
            date: today,
            minDate: today,
            maxDate: today.add(const Duration(days: 14)),
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  for (final brightness in [Brightness.light, Brightness.dark]) {
    final name = brightness == Brightness.light ? '밝은' : '어두운';

    testWidgets('$name 테마에서 날짜 칩이 배경에 묻히지 않는다', (tester) async {
      await pumpStrip(tester, brightness);

      final theme = brightness == Brightness.light
          ? buildLightTheme()
          : buildDarkTheme();
      final pageBackground = theme.colorScheme.surface;
      final (textColors: _, chipColors: chips) = collect(tester);

      expect(chips, isNotEmpty);
      for (final chip in chips) {
        expect(
          contrastRatio(chip, pageBackground),
          greaterThan(1.15),
          reason: '칩 색이 화면 배경과 거의 같아 칸이 안 보인다',
        );
      }
    });

    testWidgets('$name 테마에서 날짜 글자가 칩 위에서 읽힌다', (tester) async {
      await pumpStrip(tester, brightness);

      final (textColors: texts, chipColors: chips) = collect(tester);
      expect(texts, isNotEmpty);
      expect(texts.length, chips.length * 2); // 칩마다 요일 + 날짜

      for (var i = 0; i < texts.length; i++) {
        final chip = chips[i ~/ 2];
        expect(
          contrastRatio(texts[i], chip),
          greaterThan(3.0),
          reason: '글자가 칩 배경에 묻힌다(밝기 대비 부족)',
        );
      }
    });
  }
}
