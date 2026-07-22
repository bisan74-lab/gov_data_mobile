import 'package:golf_windy/app/app.dart';
import 'package:golf_windy/core/remote_config/app_gate_provider.dart';
import 'package:golf_windy/core/remote_config/app_gate_repository.dart';
import 'package:golf_windy/core/storage/prefs.dart';
import 'package:golf_windy/features/kma_weather/data/repositories/mock_land_weather_repository.dart';
import 'package:golf_windy/features/kma_weather/presentation/providers.dart';
import 'package:golf_windy/features/weather/data/repositories/mock_wind_field_repository.dart';
import 'package:golf_windy/features/weather/presentation/weather_screen.dart';
import 'package:golf_windy/features/weather/presentation/wind_field_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 테스트에서는 실 API 대신 목 리포지토리와 인메모리 prefs를 주입한다.
/// (기상청 키가 없으므로 예보는 Open-Meteo 자리의 목 데이터만 쓴다.)
Future<Widget> buildApp() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      landWeatherRepositoryProvider.overrideWithValue(
        MockLandWeatherRepository(),
      ),
      // Windy 탭은 실제로 열어야만 빌드되지만(지연 빌드), 탭 전환 시 실
      // 네트워크를 타지 않도록 바람장도 목으로 주입해 둔다.
      windFieldRepositoryProvider.overrideWithValue(MockWindFieldRepository()),
      // 실 네트워크 호출 없이 항상 "강제 업데이트 아님"으로 응답하게 한다.
      appGateRepositoryProvider.overrideWithValue(
        AppGateRepository(
          client: MockClient((_) async => http.Response('{}', 200)),
        ),
      ),
    ],
    child: const GolfWindyApp(),
  );
}

void main() {
  testWidgets('앱이 렌더링되고 4개 탭이 보인다', (tester) async {
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();

    expect(find.text('홈'), findsOneWidget);
    expect(find.text('날씨'), findsOneWidget);
    expect(find.text('Windy'), findsOneWidget);
    expect(find.text('설정'), findsOneWidget);
    // 홈 AppBar 타이틀.
    expect(find.text('골프윈디'), findsWidgets);
  });

  testWidgets('우측 상단 지역 선택 버튼으로 골프장 목록이 열린다', (tester) async {
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_location_alt_outlined).first);
    await tester.pumpAndSettle();

    // 목록의 첫 골프장(기본 선택)이 보인다.
    expect(find.text('라데나골프클럽'), findsWidgets);
  });

  testWidgets('Windy 탭은 실제로 열기 전까지 빌드되지 않는다(지연 빌드)', (tester) async {
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();

    // 홈만 보이는 상태에서는 Windy 탭(WeatherScreen)이 아직 빌드되지
    // 않는다 — 앱 시작 시 4탭이 전부 즉시 빌드되며 Windy의 무거운 바람장
    // 요청이 홈과 동시에 나가 홈 첫 화면이 10초 넘게 늦어지던 문제의 수정.
    expect(find.byType(WeatherScreen), findsNothing);

    await tester.tap(find.text('Windy'));
    // Windy는 파티클 애니메이션 Ticker가 있어 pumpAndSettle을 쓰지 않는다.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.byType(WeatherScreen), findsOneWidget);
  });

  testWidgets('설정 탭에 템플릿/정보가 보인다', (tester) async {
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('설정'));
    await tester.pumpAndSettle();

    expect(find.text('오류신고 및 사업제휴 문의'), findsOneWidget);
  });
}
