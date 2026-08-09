import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golf_windy/core/widgets/ad_placeholder.dart';
import 'package:golf_windy/features/home/presentation/home_screen.dart';
import 'package:golf_windy/features/kma_weather/presentation/kma_weather_screen.dart';
import 'package:golf_windy/features/settings/presentation/settings_screen.dart';

import '../widget_test.dart';

/// 홈·날씨·설정 세 화면 모두 **맨 아래에 광고 배너 자리**를 갖고, 본문은
/// 그만큼 줄어든 높이를 쓴다는 걸 확인한다.
///
/// 위젯 테스트에서는 `adsRuntimeEnabled`가 false라 실제 배너 대신 같은 높이의
/// 앱 소개 박스가 그려진다(광고 플랫폼 채널을 건드리지 않는다). **테스트에서
/// 이 값을 켜지 말 것.**
void main() {
  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();
    if (label != '홈') {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('홈 화면 맨 아래에 광고 배너 자리가 있다', (tester) async {
    await openTab(tester, '홈');

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(AdPlaceholder), findsOneWidget);
  });

  testWidgets('날씨 화면 맨 아래에 광고 배너 자리가 있다', (tester) async {
    await openTab(tester, '날씨');

    expect(find.byType(KmaWeatherScreen), findsOneWidget);
    expect(find.byType(AdPlaceholder), findsOneWidget);
  });

  testWidgets('설정 화면 맨 아래에 광고 배너 자리가 있다', (tester) async {
    await openTab(tester, '설정');

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(AdPlaceholder), findsOneWidget);
  });

  testWidgets('배너는 본문 아래에 있고 본문을 덮지 않는다', (tester) async {
    await openTab(tester, '홈');

    final banner = tester.getRect(find.byType(AdPlaceholder));
    final body = tester.getRect(find.byType(ListView).first);

    // 배너 위쪽 끝이 본문 아래쪽 끝보다 아래(또는 같은 자리)에 있어야
    // 본문을 가리지 않는다 — Column으로 쌓아 본문 높이를 줄인 결과다.
    expect(
      banner.top,
      greaterThanOrEqualTo(body.bottom - 0.5),
      reason: '광고 배너가 본문 위로 겹친다',
    );
    // 화면 안에 들어와 있어야 한다(잘려 나가면 광고가 노출되지 않는다).
    final screen = tester.getRect(find.byType(MaterialApp));
    expect(banner.bottom, lessThanOrEqualTo(screen.bottom + 0.5));
    expect(banner.height, greaterThan(0));
  });
}
