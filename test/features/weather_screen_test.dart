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
  testWidgets('지도에서 시각을 옮긴 뒤 상세 예보를 열었다 닫아도 그 시각이 유지된다', (tester) async {
    // 바다윈디에서 제보돼 고친 두 가지를 골프윈디에서도 막는 회귀 테스트다.
    //  (1) 표를 닫을 때 `_closeDetail`이 지도 시각을 "지금"으로 되돌리던 것.
    //  (2) 표를 열 때 지도의 선택 시각이 아니라 "지금" 칸부터 보여 주던 것 —
    //      이 경우 표가 열리는 순간 `_syncMapHour`가 지도 시각까지 "지금"으로
    //      끌어내려, 닫고 나면 옮겨 둔 시각이 사라진다.
    // 둘 중 하나만 깨져도 아래 마지막 기대가 실패한다.
    await pumpWeatherScreen(tester);
    final nowLabel = _mapTimeLabel(tester); // 옮기기 전 = "지금"

    // 지도 시간 바의 ▶로 몇 시간 앞으로 옮긴다.
    final next = find.byTooltip('다음 시각');
    expect(next, findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(next);
      await tester.pump(const Duration(milliseconds: 16));
    }

    // 옮긴 뒤에는 "+N시간" 같은 상대 시간 표시가 붙는다("지금"이 아니다).
    // find.text('지금')은 항상 있는 "지금" 버튼과 구분이 안 되므로 쓰지 않는다.
    expect(
      _relativeLabels(tester),
      isNotEmpty,
      reason: '시각을 옮겼는데 상대 시간 표시가 없다',
    );
    final moved = _mapTimeLabel(tester);

    // 상세 예보를 열었다가 닫는다. **표가 자리를 잡을 때까지 넉넉히
    // 프레임을 진행시킨 뒤** 닫기를 누른다 — 표가 뜨는 도중에는 예보가
    // 채워지며 패널 높이가 변해 닫기(X) 버튼이 움직이고, 그 사이에 누르면
    // 탭이 빗나가 닫히지 않는다(파티클 Ticker가 있어 pumpAndSettle은 못 쓴다).
    await tester.tap(topBarDetailIcon());
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.tap(find.byIcon(Icons.close));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    // 표는 3시간 간격이라 지도의 13:00이 12:00 칸으로 붙는 것은 정상이다.
    // 잡아야 하는 것은 **"지금"으로 되돌아가는 것** — 그러면 옮겨 둔 날짜가
    // 사라진 것처럼 보인다. 그래서 옮긴 뒤 값과 같은지가 아니라, 옮기기 전
    // ("지금") 값으로 돌아가지 않았는지를 본다.
    final after = _mapTimeLabel(tester);
    expect(after, isNot(nowLabel), reason: '상세 예보를 닫으니 지도 시각이 "지금"으로 되돌아갔다');
    expect(
      _relativeLabels(tester),
      isNotEmpty,
      reason: '상세 예보를 닫으니 지도가 "지금"으로 되돌아갔다(상대 시간 표시가 사라졌다)',
    );
    // 옮겨 둔 시각 그 자체이거나, 표의 칸 간격만큼만 붙은 값이어야 한다.
    expect(after.compareTo(nowLabel), isNot(0));
    debugPrint('지도 시각: 지금=$nowLabel → 옮김=$moved → 닫은 뒤=$after');
  });
  testWidgets('지도에서 시각을 옮긴 뒤 상세 예보를 열면 그 시각부터 보여 준다', (tester) async {
    // 표가 "지금"부터 열리면, 지도에서 애써 옮겨 둔 날짜가 사라진 것처럼
    // 보인다(바다윈디 제보로 고친 것). 표는 3시간 간격이라 지도 시각과
    // 정확히 같을 수는 없고 **가장 가까운 칸**으로 붙는다 — 그래서 두 시각의
    // 차이가 칸 간격의 절반 안쪽인지로 본다. "지금"부터 열리면 옮긴 만큼
    // (여기선 3시간) 벌어져 이 검사에 걸린다.
    await pumpWeatherScreen(tester);

    // **넉넉히 멀리 옮긴다(12시간).** 3시간만 옮기면 표의 3시간 칸에서
    // "지금 기준"과 "지도 기준"이 같은 칸으로 떨어지는 시간대가 생겨, 고쳐도
    // 안 고쳐도 통과하는 무의미한 검사가 된다(실제로 그렇게 새 버렸다).
    final next = find.byTooltip('다음 시각');
    for (var i = 0; i < 12; i++) {
      await tester.tap(next);
      await tester.pump(const Duration(milliseconds: 16));
    }
    final mapTime = _parseMapLabel(_mapTimeLabel(tester));

    await tester.tap(topBarDetailIcon());
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    final panelTime = _panelHeaderTime(tester);
    expect(
      panelTime.difference(mapTime).abs(),
      lessThanOrEqualTo(const Duration(minutes: 90)),
      reason: '상세 예보가 지도 시각($mapTime)이 아니라 딴 시각($panelTime)부터 열렸다',
    );
  });
}

/// 지도 라벨("8/30 (일) 13:00")을 [DateTime]으로. 연도는 비교에만 쓰이므로
/// 아무 값이나 넣되 양쪽을 같은 규칙으로 만든다.
DateTime _parseMapLabel(String label) {
  final m = RegExp(
    r'^(\d{1,2})/(\d{1,2}) \(.\) (\d{2}):(\d{2})$',
  ).firstMatch(label)!;
  return DateTime(
    2000,
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
    int.parse(m.group(4)!),
  );
}

/// 상세 예보 표 머리의 선택 시각("8월 30일 (일) 12:00").
DateTime _panelHeaderTime(WidgetTester tester) {
  final re = RegExp(r'^(\d{1,2})월 (\d{1,2})일 \(.\) (\d{2}):(\d{2})$');
  final hits = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data)
      .whereType<String>()
      .where(re.hasMatch)
      .toList();
  expect(hits, isNotEmpty, reason: '상세 예보 표의 선택 시각을 찾지 못했다');
  final m = re.firstMatch(hits.first)!;
  return DateTime(
    2000,
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
    int.parse(m.group(4)!),
  );
}

/// 지도 시각이 "지금"에서 벗어났을 때만 붙는 "+N시간"/"-N시간" 표시.
List<String> _relativeLabels(WidgetTester tester) {
  final re = RegExp(r'^[+-]\d+시간$');
  return tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data)
      .whereType<String>()
      .where(re.hasMatch)
      .toList();
}

/// 지도 하단 시간 바의 "월/일 (요일) 시:분" 라벨 문자열.
String _mapTimeLabel(WidgetTester tester) {
  final re = RegExp(r'^\d{1,2}/\d{1,2} \(.\) \d{2}:\d{2}$');
  final hits = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data)
      .whereType<String>()
      .where(re.hasMatch)
      .toList();
  expect(hits, isNotEmpty, reason: '지도 시간 라벨을 찾지 못했다');
  return hits.first;
}
