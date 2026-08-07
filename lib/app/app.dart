import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/remote_config/app_gate_provider.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/kma_weather/presentation/kma_weather_screen.dart';
import '../features/settings/presentation/providers.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/weather/presentation/weather_screen.dart';
import 'app_tab_provider.dart';
import 'force_upgrade_screen.dart';
import 'theme.dart';

/// 앱 전체에 거는 **글자 배율 상한**.
///
/// 안드로이드 설정 > 디스플레이 > 글자 크기(또는 접근성 "더 크게")를 올리면
/// 앱의 모든 텍스트가 그 배율만큼 커진다. 배율이 2.0까지 가면 값을 촘촘히
/// 담는 화면(상세 예보 표·홈 카드·설정)에서 글자가 겹치거나 화면 밖으로
/// 넘쳐 **오히려 못 읽게** 된다(바다윈디에서 실제 사용자 제보로 확인된
/// 문제라, 골프윈디도 같은 방식으로 미리 막는다).
///
/// 화면마다 따로 대응하는 것도 방법이지만 같은 종류가 앱 곳곳에 있어 끝이
/// 없다 — 여기서 한 번 막는 것이 확실하다.
///
/// **대가는 분명하다** — 사용자의 접근성 설정을 일부 무시한다. 그래서 값을
/// 함부로 낮추지 말 것(바다윈디는 1.3으로 시작했다가 "너무 작다"는 제보를
/// 받아 1.5로 올렸다). 이 값을 바꾸면 반드시
/// `test/features/text_scale_layout_test.dart`를 돌려 표·설정·메뉴가
/// 버티는지 확인한다.
const double kMaxTextScale = 1.5;

/// [kMaxTextScale]을 적용한다. `MaterialApp.builder`에 그대로 넘기면 앱 안
/// 모든 화면에 걸린다. **테스트 하네스도 같은 함수를 써야** 실제 화면과 같은
/// 조건으로 검사된다.
Widget clampAppTextScale(BuildContext context, Widget? child) {
  final mq = MediaQuery.of(context);
  return MediaQuery(
    data: mq.copyWith(
      textScaler: mq.textScaler.clamp(maxScaleFactor: kMaxTextScale),
    ),
    child: child ?? const SizedBox.shrink(),
  );
}

/// 앱 진입점. `appGateProvider`가 강제 업데이트 상태(`forceUpgrade: true`)를
/// 돌려주면 [AppShell] 대신 [ForceUpgradeScreen]을 띄워 실행을 막는다 —
/// 무료 배포본을 나중에 광고 버전으로 전환할 때, 앱 재배포 없이
/// `remote_config/app_gate.json`의 값만 바꾸면 모든 설치 기기에 적용된다.
/// 설정 확인이 안 되면(오프라인 등) 항상 앱을 정상 실행한다.
class GolfWindyApp extends ConsumerWidget {
  const GolfWindyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gateAsync = ref.watch(appGateProvider);
    final skin = ref.watch(skinProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: '골프윈디',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(skin.seed),
      darkTheme: buildDarkTheme(skin.seed),
      themeMode: themeMode,
      // 모든 화면에 한 번에 적용된다([kMaxTextScale] 참고).
      builder: clampAppTextScale,
      home: gateAsync.when(
        data: (gate) => gate.forceUpgrade
            ? ForceUpgradeScreen(config: gate)
            : const AppShell(),
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (_, _) => const AppShell(),
      ),
    );
  }
}

/// 하단 탭 기반 앱 셸: 홈 / 날씨 / Windy / 설정.
/// 홈·날씨·Windy는 모두 공용으로 선택된 골프장을 따른다.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const _screens = [
    HomeScreen(),
    KmaWeatherScreen(),
    WeatherScreen(),
    SettingsScreen(),
  ];

  /// 실제로 한 번이라도 연 탭의 인덱스만 화면을 만든다. 그렇지 않으면
  /// `IndexedStack`이 시작 시 4탭을 전부 즉시 빌드해, 아직 보지도 않은
  /// Windy 탭의 무거운 바람장(16일치) 요청이 홈 화면의 예보 요청과 동시에
  /// 나가 서로 대역폭을 다투면서 홈 첫 화면이 10초 넘게 늦어졌다. 탭을 한
  /// 번 열면 이후엔 계속 유지해 상태(스크롤 위치 등)를 보존한다.
  final Set<int> _visited = {0};

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(appTabIndexProvider);
    _visited.add(index);
    // Windy(몰입형 지도) 탭에서는 하단 라벨 바를 숨긴다 — 그 탭 안에서 오른쪽
    // 세로 아이콘 내비게이션을 띄운다. 나머지 탭은 원래 하단 라벨 내비게이션.
    final onWindy = index == windyTabIndex;
    return Scaffold(
      body: IndexedStack(
        index: index,
        // 화면 밖 탭(특히 애니메이션이 있는 Windy 탭)의 Ticker를 꺼서
        // 불필요한 리빌드와 배터리 소모, pumpAndSettle 무한대기를 막는다.
        children: [
          for (var i = 0; i < _screens.length; i++)
            TickerMode(
              enabled: i == index,
              child: _visited.contains(i)
                  ? _screens[i]
                  : const SizedBox.shrink(),
            ),
        ],
      ),
      bottomNavigationBar: onWindy
          ? null
          : NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (i) =>
                  ref.read(appTabIndexProvider.notifier).state = i,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: '홈',
                ),
                NavigationDestination(
                  icon: Icon(Icons.wb_sunny_outlined),
                  selectedIcon: Icon(Icons.wb_sunny),
                  label: '날씨',
                ),
                NavigationDestination(
                  icon: Icon(Icons.air_outlined),
                  selectedIcon: Icon(Icons.air),
                  label: 'Windy',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: '설정',
                ),
              ],
            ),
    );
  }
}
