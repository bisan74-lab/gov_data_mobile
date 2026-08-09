import 'package:golf_windy/app/app.dart';
import 'package:golf_windy/app/app_tab_provider.dart';
import 'package:golf_windy/core/remote_config/app_gate_provider.dart';
import 'package:golf_windy/core/remote_config/app_gate_repository.dart';
import 'package:golf_windy/core/storage/prefs.dart';
import 'package:golf_windy/features/golf/presentation/widgets/golf_marker_layer.dart';
import 'package:golf_windy/features/kma_weather/data/repositories/mock_land_weather_repository.dart';
import 'package:golf_windy/features/kma_weather/presentation/providers.dart';
import 'package:golf_windy/features/locations/data/sample_locations.dart';
import 'package:golf_windy/features/locations/presentation/providers.dart';
import 'package:golf_windy/features/weather/data/repositories/mock_wind_field_repository.dart';
import 'package:golf_windy/features/weather/presentation/weather_screen.dart';
import 'package:golf_windy/features/weather/presentation/wind_field_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [buildApp]과 같은 오버라이드를 쓰되, `container.read(...).select(...)`로
/// 직접 지역을 바꿀 수 있도록 [ProviderContainer]를 노출한다.
Future<ProviderContainer> buildAppContainer() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
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
  );
}

/// Windy 탭 지도 위 골프장 마커(초록 점)의 화면 중심 좌표.
Offset? golfMarkerDotCenter(WidgetTester tester) {
  final dotFinder = find.descendant(
    of: find.byType(GolfMarkerLayer),
    matching: find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).shape == BoxShape.circle,
    ),
  );
  if (dotFinder.evaluate().isEmpty) return null;
  return tester.getCenter(dotFinder.first);
}

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

  testWidgets('다른 탭에서 골프장을 바꾼 뒤 Windy 탭으로 돌아와도 그 골프장이 화면 가운데로 온다', (
    tester,
  ) async {
    final target = sampleLocations[1];

    // 기준값: Windy 탭이 떠 있는 상태(하단 내비바 없음, 화면 전체 크기)
    // 에서 곧바로 target을 선택했을 때의 마커 위치.
    final refContainer = await buildAppContainer();
    addTearDown(refContainer.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: refContainer,
        child: const GolfWindyApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    refContainer.read(appTabIndexProvider.notifier).state = windyTabIndex;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));

    refContainer.read(selectedLocationProvider.notifier).select(target);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    final refDot = golfMarkerDotCenter(tester);
    expect(refDot, isNotNull);

    // 재현 시나리오: Windy 탭을 한 번 열어 둔 채(IndexedStack에 살아있는
    // 상태) 홈 탭으로 돌아간다 — 이때 하단 내비게이션 바가 다시 뜨며
    // Scaffold 본문이 좁아지는데, `IndexedStack`은 화면 밖 Windy 탭도
    // 계속 레이아웃한다. 이 좁아진 화면 크기가 남아 있는 채로 골프장을
    // 바꾸면(재중심이 그 순간 실행됨) 잘못된 크기로 중심을 계산했던
    // 버그의 회귀 테스트.
    final reproContainer = await buildAppContainer();
    addTearDown(reproContainer.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: reproContainer,
        child: const GolfWindyApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    reproContainer.read(appTabIndexProvider.notifier).state = windyTabIndex;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));

    reproContainer.read(appTabIndexProvider.notifier).state = 0;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    reproContainer.read(selectedLocationProvider.notifier).select(target);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));

    reproContainer.read(appTabIndexProvider.notifier).state = windyTabIndex;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));

    final reproDot = golfMarkerDotCenter(tester);
    expect(reproDot, isNotNull);

    // 다른 탭에서 바꿨든 Windy 탭에서 바꿨든, 같은 골프장은 같은 화면
    // 위치(가운데)에 와야 한다.
    expect(reproDot!.dx, closeTo(refDot!.dx, 1.0));
    expect(reproDot.dy, closeTo(refDot.dy, 1.0));
  });

  testWidgets('설정 탭에 템플릿/정보가 보인다', (tester) async {
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('설정'));
    await tester.pumpAndSettle();

    expect(find.text('오류신고 및 사업제휴 문의'), findsOneWidget);

    // **"광고 제거"(인앱 결제) 항목은 없어야 한다.** 그런 상품이 아직
    // 없는데 메뉴만 두면 눌러 본 사용자에게 "준비 중"만 보여 주게 되고,
    // 스토어 심사에서도 없는 기능을 안내하는 셈이 된다(사용자 요구로 삭제).
    expect(find.text('광고 제거'), findsNothing);
    expect(find.byIcon(Icons.workspace_premium_outlined), findsNothing);
  });
}
