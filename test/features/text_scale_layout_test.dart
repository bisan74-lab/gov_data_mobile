/// 시스템 글자 크기를 키웠을 때 화면이 깨지지 않는지 검사한다.
///
/// 안드로이드 설정 > 디스플레이 > 글자 크기를 크게 하면 앱의 모든 텍스트가
/// 배율만큼 커진다. 고정 폭·고정 높이에 글자를 넣어 둔 곳은 이때 **겹치거나
/// 화면 밖으로 넘친다**. 바다윈디에서 실제 사용자 제보로 확인된 문제라,
/// 골프윈디도 같은 방식으로 미리 막는다.
///
/// Flutter는 `RenderFlex overflowed by ...` 같은 오버플로를 페인트 단계에서
/// 예외로 던지므로, 각 화면을 **여러 배율 × 여러 화면 크기**로 그려 보고
/// `tester.takeException()`에 아무것도 안 잡히는지 보면 된다.
library;

import 'package:golf_windy/app/app.dart';
import 'package:golf_windy/core/remote_config/app_gate_provider.dart';
import 'package:golf_windy/core/remote_config/app_gate_repository.dart';
import 'package:golf_windy/core/storage/prefs.dart';
import 'package:golf_windy/features/compass/presentation/wind_compass_screen.dart';
import 'package:golf_windy/features/home/presentation/home_screen.dart';
import 'package:golf_windy/features/kma_weather/data/repositories/mock_land_weather_repository.dart';
import 'package:golf_windy/features/kma_weather/presentation/kma_weather_screen.dart';
import 'package:golf_windy/features/kma_weather/presentation/providers.dart';
import 'package:golf_windy/features/settings/presentation/settings_screen.dart';
import 'package:golf_windy/features/weather/data/repositories/mock_wind_field_repository.dart';
import 'package:golf_windy/features/weather/presentation/weather_screen.dart';
import 'package:golf_windy/features/weather/presentation/wind_field_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 검사할 글자 배율.
///
/// 안드로이드 "글자 크기" 슬라이더는 대략 0.85~1.3, **접근성 설정의 "더 크게"**
/// 까지 가면 1.5~2.0까지 올라간다. 앱 상한([kMaxTextScale])이 1.5라 실제
/// 적용되는 배율은 최대 1.5지만, 시스템이 그 이상을 줘도 버티는지 보려고
/// 2.0까지 넣어 검사한다.
const scales = <double>[1.0, 1.3, 1.6, 2.0];

/// 검사할 화면 크기(논리 픽셀). 작은 기기일수록 먼저 깨진다.
/// **크기를 함부로 줄이지 말 것** — 겹침은 특정 조합에서만 난다(바다윈디에서
/// 제보된 메뉴 겹침은 360×780 · 1.6배에서만 재현됐다).
/// 화면은 세로 고정이므로 세로 크기만 둔다.
const sizes = <(String, Size)>[
  ('작은 폰 360×640', Size(360, 640)),
  ('세로 긴 폰 360×780', Size(360, 780)),
  ('보통 폰 412×915', Size(412, 915)),
];

Future<Widget> wrap(Widget child) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      landWeatherRepositoryProvider.overrideWithValue(
        MockLandWeatherRepository(),
      ),
      windFieldRepositoryProvider.overrideWithValue(MockWindFieldRepository()),
      appGateRepositoryProvider.overrideWithValue(
        AppGateRepository(
          client: MockClient((_) async => http.Response('{}', 200)),
        ),
      ),
    ],
    // **앱과 같은 글자 배율 상한을 건다**(`kMaxTextScale`). 이걸 빼면
    // 실제 화면보다 가혹한 조건으로 검사해 없는 문제를 쫓게 된다.
    child: MaterialApp(builder: clampAppTextScale, home: child),
  );
}

/// [child]를 [size] 화면 · [scale] 배율로 그리고, 오버플로가 나면 그 내용을
/// 문자열로 돌려준다(없으면 null).
Future<String?> renderAndCatch(
  WidgetTester tester,
  Widget child, {
  required Size size,
  required double scale,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
      child: await wrap(child),
    ),
  );
  // 파티클 애니메이션이 계속 돌아 pumpAndSettle은 멈추지 않는다.
  await tester.pump();
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }

  final e = tester.takeException();
  return e?.toString().split('\n').first;
}

void main() {
  final failures = <String>[];

  Future<void> check(
    WidgetTester tester,
    String screen,
    Widget Function() build,
  ) async {
    for (final (sizeName, size) in sizes) {
      for (final scale in scales) {
        final err = await renderAndCatch(
          tester,
          build(),
          size: size,
          scale: scale,
        );
        if (err != null) {
          failures.add('$screen · $sizeName · 배율 ${scale}x → $err');
        }
      }
    }
  }

  testWidgets('홈 화면이 큰 글자에서도 넘치지 않는다', (tester) async {
    failures.clear();
    await check(tester, '홈', HomeScreen.new);
    expect(failures, isEmpty, reason: '\n${failures.join('\n')}');
  });

  testWidgets('날씨 화면이 큰 글자에서도 넘치지 않는다', (tester) async {
    failures.clear();
    await check(tester, '날씨', KmaWeatherScreen.new);
    expect(failures, isEmpty, reason: '\n${failures.join('\n')}');
  });

  testWidgets('바람지도 화면이 큰 글자에서도 넘치지 않는다', (tester) async {
    failures.clear();
    await check(tester, '바람지도', WeatherScreen.new);
    expect(failures, isEmpty, reason: '\n${failures.join('\n')}');
  });

  testWidgets('설정 화면이 큰 글자에서도 넘치지 않는다', (tester) async {
    failures.clear();
    await check(tester, '설정', SettingsScreen.new);
    expect(failures, isEmpty, reason: '\n${failures.join('\n')}');
  });

  testWidgets('앱 셸(탭 바 포함)이 큰 글자에서도 넘치지 않는다', (tester) async {
    failures.clear();
    await check(tester, '앱 셸', AppShell.new);
    expect(failures, isEmpty, reason: '\n${failures.join('\n')}');
  });

  testWidgets('바람나침판 화면이 큰 글자에서도 넘치지 않는다', (tester) async {
    failures.clear();
    await check(tester, '바람나침판', WindCompassScreen.new);
    expect(failures, isEmpty, reason: '\n${failures.join('\n')}');
    // 위치 조회 시간 제한·센서 대기 타이머를 흘려 보낸다(남으면 실패로 잡힌다).
    await tester.pump(const Duration(seconds: 16));
  });
}
