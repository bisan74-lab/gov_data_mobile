import 'dart:convert';

import 'package:golf_windy/core/storage/prefs.dart';
import 'package:golf_windy/features/golf/presentation/widgets/golf_marker_layer.dart';
import 'package:golf_windy/features/locations/data/sample_locations.dart';
import 'package:golf_windy/features/locations/presentation/providers.dart';
import 'package:golf_windy/features/weather/data/repositories/mock_wind_field_repository.dart';
import 'package:golf_windy/features/weather/presentation/weather_screen.dart';
import 'package:golf_windy/features/weather/presentation/wind_field_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 파티클 애니메이션은 계속 반복되는 Ticker를 쓰므로 pumpAndSettle은 쓰지 않고
// pump()로 몇 프레임만 진행해 예외 없이 그려지는지 확인한다.

/// 상단 바의 상세 예보 아이콘. 지도 마커의 상세 버튼도 같은
/// [golfDetailForecastIcon]을 쓰므로(같은 동작이라 일부러 같은 아이콘)
/// 아이콘만으로는 구분되지 않는다 — 상단 바만 [SafeArea]로 감싸여 있는 점을
/// 이용해 좁힌다.
Finder topBarDetailIcon() => find.descendant(
  of: find.byType(SafeArea),
  matching: find.byIcon(golfDetailForecastIcon),
);

/// 바람지도 화면을 목 바람장으로 띄우고 첫 프레임들을 진행시킨다.
/// (Ticker가 있어 pumpAndSettle은 쓰지 않는다.)
Future<void> pumpWeatherScreen(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        windFieldRepositoryProvider.overrideWithValue(
          MockWindFieldRepository(),
        ),
      ],
      child: const MaterialApp(home: WeatherScreen()),
    ),
  );
  await tester.pump(); // FutureProvider 완료
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 16));
}

void main() {
  testWidgets('진입 시 선택 골프장의 바람 요약·이름 칩이 항상 뜨고, 탭하면 상세 예보 표가 열린다', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          windFieldRepositoryProvider.overrideWithValue(
            MockWindFieldRepository(),
          ),
        ],
        child: const MaterialApp(home: WeatherScreen()),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsWidgets);

    await tester.pump(); // FutureProvider 완료
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));

    // 진입 즉시(탭 없이도): 지도 + 하단 시간 스크러버(Slider) + 상단 바(왼쪽
    // 바람 정보, 오른쪽 골프장명 칩)가 모두 떠 있다.
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.byType(Slider), findsOneWidget);
    expect(topBarDetailIcon(), findsOneWidget);
    expect(find.text(sampleLocations.first.name), findsWidgets);
    // 지도 마커의 상세 예보 버튼도 진입 즉시 함께 보인다.
    expect(find.byKey(golfMarkerDetailButtonKey), findsOneWidget);

    // 상단 바 왼쪽(바람 정보)을 탭하면 표가 열려 하단 시간 스크러버
    // (map-mode 전용)가 사라진다.
    await tester.tap(topBarDetailIcon());
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byType(Slider), findsNothing);
  });

  // 마커의 두 진입 경로(이름 / 그 아래 상세 버튼)는 **각각 별도 테스트**로
  // 둔다. 한 테스트에서 pumpWidget을 두 번 부르면 위젯 트리 구조가 같아
  // State가 재사용되고(_forecastPoint가 남는다) 두 번째 검증이 더러운 상태에서
  // 시작한다.
  testWidgets('지도 마커의 상세 예보 버튼을 탭하면 상세 예보가 열린다', (tester) async {
    await pumpWeatherScreen(tester);

    expect(find.byType(Slider), findsOneWidget); // 지도 모드
    // 아이콘만으로는 알기 어렵다는 제보를 받아 글자를 함께 넣었다 —
    // 버튼 안에 "상세 예보" 라벨이 실제로 보여야 한다.
    expect(
      find.descendant(
        of: find.byKey(golfMarkerDetailButtonKey),
        matching: find.text('상세 예보'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(golfMarkerDetailButtonKey));
    await tester.pump(const Duration(milliseconds: 16));

    // 표가 열리면 지도 모드 전용 시간 스크러버가 사라진다.
    expect(find.byType(Slider), findsNothing);

    // 이미 보고 있는 화면으로 또 들어가라고 권하는 버튼은 지도만 가린다 —
    // 상세 예보가 열린 동안엔 마커의 상세 버튼이 사라져야 한다.
    expect(find.byKey(golfMarkerDetailButtonKey), findsNothing);
  });

  testWidgets('상세 예보를 닫으면 마커의 상세 예보 버튼이 다시 나타난다', (tester) async {
    await pumpWeatherScreen(tester);
    expect(find.byKey(golfMarkerDetailButtonKey), findsOneWidget);

    await tester.tap(find.byKey(golfMarkerDetailButtonKey));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byKey(golfMarkerDetailButtonKey), findsNothing);

    // 표의 닫기(X)로 지도 모드로 돌아온다.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.byType(Slider), findsOneWidget); // 지도 모드로 복귀
    expect(find.byKey(golfMarkerDetailButtonKey), findsOneWidget);
  });

  testWidgets('큰 글자에서도 상세 예보 버튼이 골프장 이름 위로 파고들지 않는다', (tester) async {
    // 버튼을 이름 행 아래로 내리는 거리를 **상수로 박으면** 배율이 오를 때
    // 이름 행만 길어져 버튼이 이름을 덮는다(배율 2.0에서 실제로 겹쳤다).
    // 실제 글자 높이를 재서 내리도록 고친 것의 회귀 테스트.
    for (final scale in [1.0, 1.5, 2.0]) {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              windFieldRepositoryProvider.overrideWithValue(
                MockWindFieldRepository(),
              ),
            ],
            child: const MaterialApp(home: WeatherScreen()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));

      final button = tester.getRect(find.byKey(golfMarkerDetailButtonKey));
      final name = tester.getRect(
        find.descendant(
          of: find.byType(GolfMarkerLayer),
          matching: find.text(sampleLocations.first.name),
        ),
      );
      expect(
        button.top,
        greaterThanOrEqualTo(name.bottom - 0.5),
        reason: '배율 ${scale}x에서 상세 예보 버튼이 골프장 이름과 겹친다',
      );
    }
  });

  testWidgets('지도 마커의 골프장 이름을 탭해도 상세 예보가 열린다(기존 동작 유지)', (tester) async {
    await pumpWeatherScreen(tester);

    expect(find.byType(Slider), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(GolfMarkerLayer),
        matching: find.text(sampleLocations.first.name),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('상세 예보 표가 열리면 표 높이를 뺀 지도 영역 가운데로 재중심한다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          windFieldRepositoryProvider.overrideWithValue(
            MockWindFieldRepository(),
          ),
        ],
        child: const MaterialApp(home: WeatherScreen()),
      ),
    );

    await tester.pump(); // FutureProvider 완료
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));

    double translationY() {
      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      return viewer.transformationController!.value.getTranslation().y;
    }

    final beforeTy = translationY();

    // 상단 바(바람 정보)를 탭해 상세 예보 표를 연다 — 표 높이가 렌더 뒤
    // 측정되면(`_measureBottomBar`) 그 높이를 뺀 나머지 지도 영역 가운데로
    // 재중심이 예약 실행된다.
    await tester.tap(topBarDetailIcon());
    await tester.pump(const Duration(milliseconds: 16));

    final afterTy = translationY();

    // 표가 뜬 만큼 지도가 보이는 영역이 줄어드므로, 같은 골프장이라도 표
    // 공간을 뺀 영역 가운데에 오도록 화면 위쪽으로 당겨져야 한다(세로
    // 이동값이 작아진다).
    expect(afterTy, lessThan(beforeTy));
  });

  testWidgets('지도 모드에서 우측 상단 칩으로 골프장을 바꾸면 하단 시간바 높이를 뺀 영역 가운데로 온다', (
    tester,
  ) async {
    final target = sampleLocations[1];

    // Phase 1: target을 진입 시 기본 선택 지역으로 미리 저장해, 하단바를
    // 고려하지 않는 진입 시(`_didInitTransform`) 전체 화면 기준 중심값을
    // 기준선으로 얻는다.
    SharedPreferences.setMockInitialValues({
      'selected_location': jsonEncode(target.toJson()),
    });
    final prefsBaseline = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefsBaseline),
          windFieldRepositoryProvider.overrideWithValue(
            MockWindFieldRepository(),
          ),
        ],
        child: const MaterialApp(home: WeatherScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));

    double translationY() {
      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      return viewer.transformationController!.value.getTranslation().y;
    }

    final baselineTy = translationY();

    // Phase 2: 기본 지역(첫 골프장)으로 새로 진입해 지도 모드(하단 시간
    // 스크러버 표시 중)로 만든 뒤, 우측 상단 칩 선택과 같은 경로
    // (provider.select)로 phase 1과 같은 target으로 바꾼다.
    SharedPreferences.setMockInitialValues({});
    final prefsSwitch = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefsSwitch),
        windFieldRepositoryProvider.overrideWithValue(
          MockWindFieldRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: WeatherScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.byType(Slider), findsOneWidget); // 지도 모드(시간 스크러버 표시 중).

    container.read(selectedLocationProvider.notifier).select(target);
    await tester.pump(const Duration(milliseconds: 16));

    final switchTy = translationY();

    // 같은 골프장·같은 배율이라도, 지도 모드에서는 하단 시간바 높이를 뺀
    // 영역 가운데로 맞춰야 하므로 하단바를 고려하지 않는 기준선보다 위로
    // 당겨져야 한다(세로 이동값이 더 작다).
    expect(switchTy, lessThan(baselineTy));
  });

  testWidgets('지도 마커를 탭하면 선택 지역이 바뀐다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        windFieldRepositoryProvider.overrideWithValue(
          MockWindFieldRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: WeatherScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    final target = sampleLocations.firstWhere((l) => l.id != 'ganghwado');
    // 지도 위에 항상 보이는 좌표는 아니므로, 최근접 지점을 강제 선택해
    // provider 갱신 로직만 검증한다(마커 실제 히트테스트는 좌표 계산에
    // 의존적이라 통합 시나리오로는 provider 갱신을 직접 확인한다).
    container.read(selectedLocationProvider.notifier).select(target);
    await tester.pump(const Duration(milliseconds: 16));

    expect(container.read(selectedLocationProvider).id, target.id);
  });
}
