# 골프윈디 (GolfWindy)

Flutter 앱. 전국 골프장의 **날짜·시간대별 바람(풍향·풍속)과 날씨**를 예보하는
무료 한국어 앱. "골프장 단위의 Windy". Android 우선, iOS 확장 전제.

data.go.kr(공공데이터포털) 기반 신규 프로젝트로, BadaMobile(바다윈디)의 공공 API
연동·캐싱·Windy 스타일 바람 지도 인프라를 이식해 만들었다. **기획·화면 설계는
[docs/PLAN.md](docs/PLAN.md)를 먼저 읽는다.**

## 화면 구성 (4 탭)

앱 셸은 `app/app.dart` + `app/app_tab_provider.dart`(`appTabIndexProvider`).
Windy 탭은 몰입형 지도라 하단 라벨바를 숨기고, 지도 안 우측 아이콘 레일로 탭을 옮긴다.

- **홈**: 골프장 정보(홀·유형·주소) + 날짜별 **라운딩 지수** + **추천 옷차림** +
  티타임대 **시간대별 바람** + **라운드 컨디션 카드**(일출·일몰·자외선·습도).
  라운딩 지수 카드 **위 오른쪽**에 **바람나침판** 버튼(`windCompassButtonKey`).
- **날씨**: 선택 골프장의 시간별/일별 예보(시간별 카드에 풍향·풍속 강조)
- **Windy**: 바람 지도(BadaMobile 이식) 진입 시 **선택 골프장이 화면 중앙에
  고정·확대**된다. 지도 탭으로 다른 지점을 찍는 기능은 없고(임의 지역 선택
  불필요), **선택된 골프장 하나만** 마커로 표시된다(`GolfMarkerLayer`) — 그
  이름을 탭하면 상세 예보로 들어가고, **이름 바로 아래 "상세 예보"
  버튼**(`golfMarkerDetailButtonKey`, 표 아이콘 + 글자)을 탭해도 똑같이
  들어간다 — 이름만 탭 가능하던 시절엔 탭할 수 있다는 걸 알아채기
  어려웠고, 아이콘만 뒀을 때도 "무슨 아이콘인지 모르겠다"는 제보를 받아
  글자를 함께 넣었다. 아이콘은 `golfDetailForecastIcon` 한 곳에 정의하고
  상단 바와 **같은 아이콘**을 쓴다(같은 동작이므로).
  **상세 예보가 이미 열려 있으면 이 버튼은 숨긴다**
  (`showDetailButton: widget.forecastPoint == null`) — 보고 있는 화면으로 또
  들어가라고 권하는 꼴이라 지도만 가린다(사용자 요구). 이름 탭은 그대로
  살아 있어 동작이 사라지진 않고, 표를 닫으면 버튼이 다시 나타난다.
  **버튼을 내리는 거리는 상수로 박으면 안 된다** — 글자 배율이 오르면
  이름 행만 길어져 버튼이 이름을 덮는다(배율 2.0에서 실제로 겪었다).
  `_nameRowHalfHeight(context)`가 실제 글자 높이를 재서 정한다. 맨 위 상단
  바(왼쪽: 항상 떠 있는 선택 골프장의 바람 세기·방향 — 탭하면 상세 예보,
  오른쪽: 골프장명 칩 — 탭하면 검색으로 지역 변경)와 우측 세로 아이콘
  내비게이션이 있다.
- **설정**: 색상 스킨(기본 페어웨이 그린)·밝기·배경·정책·강제 업데이트 게이트
- **바람나침판**(탭이 아니라 홈에서 여는 화면, `features/compass/`):
  휴대폰을 수평으로 놓으면 동서남북이 **실제 방위에 고정**되고, 그 위에
  **현재 위치의 바람이 불어오는 방향**이 바깥에서 가운데를 향하는 화살표로
  얹힌다. 하단 문구는 `windCompassCaption`(사용자 지정, 바꾸지 말 것).

홈·날씨·Windy는 공용 `selectedLocationProvider`(선택 골프장)를 따른다.
**바람나침판만 예외** — `currentGpsLocationProvider`(GPS 현재 위치)를 쓴다.
"지금 내가 서 있는 자리의 바람"이 목적이라 고른 골프장을 따라가면 안 된다.
추천 로직(라운딩 지수·옷차림)은 `features/golf/logic/golf_advice.dart`(순수 함수, 테스트 대상).

## 바다윈디 지도 재동기화 가이드

`features/weather/presentation/weather_screen.dart`와 그 위젯들은 바다윈디의
Windy 지도를 이식·개조한 것이다. **골프윈디 커스터마이징은 파일 최상단 doc
주석과 코드 곳곳의 `// GOLF:` 주석으로 표시해 뒀다** — 다음에 바다윈디에서
지도 개선을 다시 가져올 때는:

1. **그대로 덮어써도 되는 순수 복사본**(바다윈디 원본과 동일, 골프 특화 없음):
   `widgets/map_projection.dart`, `widgets/coastline_painter.dart`,
   `widgets/country_borders_data.dart`, `widgets/map_city_labels.dart`,
   `widgets/wind_heatmap.dart`, `widgets/wind_map_painter.dart`,
   `data/models/wind_field.dart`,
   `data/repositories/{open_meteo_wind_field,github_wind_field,caching_wind_field,wind_field}_repository.dart`.
   → 바다윈디 최신본으로 그냥 교체한다.
2. **골프 커스터마이징이 섞인 파일**(`weather_screen.dart`): `// GOLF:` 주석이
   붙은 블록만 남기고 나머지(히트맵/파티클/해안선/도시 라벨/시간 스크러버/
   상세 예보 표/`_ForecastRose` 등)를 바다윈디 최신본으로 교체한다. 현재
   GOLF 커스터마이징 목록: 지도는 항상 **선택 골프장에 고정**(임의 지점 탭
   비활성화), 마커는 **선택된 곳 하나만**(`GolfMarkerLayer`, 이름 탭 또는
   이름 밑 상세 버튼 탭→상세 예보 — 상세 버튼은 이름 행과 **한 Column으로
   묶지 않고 따로 그린다**. 묶으면 전체 높이가 커져 앵커 보정
   `FractionalTranslation(-0.5)` 이동량이 함께 늘어 초록 점이 실제 좌표보다
   위로 밀린다), 상단 바(바람 정보+골프장명 칩)는 **항상** 표시(바다윈디는 탭해야
   뜨는 임시 커서 바였음), `pointSeaLocation`은 미사용이지만 diff 최소화를
   위해 그대로 남겨 둠. 상세 예보 표가 열리면(마커/상단 바 탭, 또는 표가
   열린 채로 우측 상단 칩으로 골프장을 바꿔도) 골프장이 **표 공간을 뺀
   나머지 지도 영역 가운데**로 재중심된다 — `focusTarget`
   ValueNotifier가 `(location, bottomInset)` 레코드를 실어 보내고,
   `_measureBottomBar()`가 표 높이를 측정한 뒤 재중심을 실행한다
   (`_pendingRecenter`/`_requestFocus`/`_onFocusRequested`). 화면 크기가
   실제로 바뀌면(다른 탭 → Windy 탭 전환 등, `IndexedStack`이 화면 밖
   탭도 계속 레이아웃해 하단 내비바 유무로 크기가 달라짐) 마지막 포커스
   대상으로 다시 중심을 맞춘다(`screenChanged`).
   **상세 예보 표에서 너울·너울2·파력·수온 네 줄은 뺐다**(`rows`와 그에
   대응하는 셀). 골프장은 모두 육지라 해양 항목이 의미가 없고, 육지
   좌표로 뽑히는 파고·수온은 근처 **바다 격자**에서 끌어온 값이라 그
   골프장의 값처럼 오해만 준다(사용자 요구). 바다윈디에서 표를 다시
   가져올 때 **되살리지 말 것** — `_ForecastRose`의 너울 막대 둘도 같은
   이유로 뺐고 바람 막대만 남겼다. `rows`와 셀 개수는 항상 같아야 한다.
   히트맵 스크럽 성능 최적화(`_HeatmapPair`/`_coreBounds`/
   `_rebuildHeatmap`/`_bakeCoreIfNeeded`, 시간 슬라이더 `onScrubbing`),
   `visibleBounds` 기반 도시 라벨 뷰포트 필터, `field.hasData` 회색
   오버레이는 바다윈디 원본 그대로이며 GOLF 커스터마이징이 섞이지
   않았다(2026-07 재동기화로 반영).
3. **완전히 골프 전용이라 바다윈디에 없는 파일**(그대로 유지, 병합 대상
   아님): `features/golf/presentation/widgets/golf_marker_layer.dart`,
   `golf_search_sheet.dart`, `features/golf/data/`, `features/golf/logic/`.

## 진행 현황 (2026-07 기준)

브랜치 `claude/data-go-kr-mobile-app-cvz6mp`에서 개발. **완료**: 4탭 셸, 홈/날씨/Windy/
설정, Windy 지도 BadaMobile 최신 재동기화(몰입형 UI·16일·bbox 18~57/108~148),
기상청 **단기예보+초단기예보+초단기실황** 병합 연동(우선순위: 실황>초단기예보>단기예보,
`data_go_kr_kma_repository.dart`), 풍향(VEC) 반영, 전국 골프장 **실데이터 531곳**.
2026-07 재동기화로 바람 데이터·지도 색상·성능이 바다윈디 최신본과 다시
맞춰졌다: 바람장 쌍3차(bicubic) 보간 + 적응형(비균일) 공간·시간 격자,
히트맵 난류 텍스처·아이솔레이트 병렬 렌더링, 스크럽 중 고해상도 핵심영역
빌드를 미루는 성능 최적화(지도 날짜이동 체감 속도 개선), `visibleBounds`
기반 도시 라벨 뷰포트 필터. **바람장은 골프윈디가 직접 수집하지 않고
바다윈디의 공개 데이터 저장소(`bisan74-lab/badawindy-data`)를 그대로
쓴다** — 두 앱의 지도 bbox·격자 포맷이 완전히 같아(재동기화로 맞춤),
같은 걸 Open-Meteo에 또 요청하면 순수 낭비이자 호출 한도 이중 소모라
골프윈디만의 fetch_wind.py/크론은 두지 않기로 했다(2026-08 재점검).
`flutter analyze` 0 · `flutter test` 통과 상태 유지.

**저장소 비공개 전환 준비 완료, 실제 전환만 남음**: `gov_data_mobile`을
최종적으로 비공개로 돌리기로 했다(현재 공개). 바다윈디도 같은 이유로
코드 저장소는 비공개, 공개 자산(바람장·게이트 설정)만 별도 공개 데이터
저장소에 두는 방식으로 전환한 전례가 있어 같은 패턴을 따랐다.
- 바람장: 위에 적었듯 골프윈디 자체 파일 없이 `badawindy-data`를 그대로
  씀 — 비공개 전환과 무관하게 이미 안전.
- force-upgrade 게이트: 사용자가 만들어 준 공개 데이터 저장소
  `bisan74-lab/golfwindy-data`에 `app_gate.json`을 옮기고
  `Env.forceUpgradeConfigUrl` 기본값을 그리로 갱신 완료
  (`raw.githubusercontent.com/bisan74-lab/golfwindy-data/main/app_gate.json`,
  공개 접근 확인함). `gov_data_mobile`의 `remote_config/app_gate.json`은
  이관 전 원본 기록용으로 남아 있을 뿐 더는 앱이 읽지 않는다 — 값을 바꿀
  땐 이제 `golfwindy-data` 쪽 파일을 갱신해야 한다.
- **남은 건 저장소 자체를 Private으로 바꾸는 것뿐**이며, 이건 저장소
  설정(Danger Zone) 변경이라 계정 소유자만 할 수 있어 이 세션이 대신
  못 한다. 전환 전 참고: **Private 저장소는 GitHub Actions 무료 사용량이
  계정 플랜별로 제한**된다(Public은 무제한) — 릴리스 빌드·테스트가
  잦다면 확인 필요. 전환 후 `test-build-N` APK 다운로드 링크도 로그인
  (권한 있는 계정) 없이는 못 받게 된다.

**미완/유의**: 실기기 APK는 GitHub Actions `release-apk.yml`로만 가능한데 워크플로가
기본 브랜치(main)에 있어야 실행되며 현재 main이 비어 있어 트리거 불가(이 개발 환경은
data.go.kr·odcloud·dl.google.com·지오코더가 모두 프록시 차단). 골프장 좌표는 시/군/구
중심 근사치라 정밀 좌표 갱신 여지 있음(아래 참고).

## 자주 쓰는 명령

```bash
flutter analyze          # 커밋 전 필수, 이슈 0이어야 함
flutter test             # 전체 테스트
dart format lib test     # 커밋 전 포맷
```

로컬 Android SDK 없이 실기기 APK가 필요하면 GitHub Actions `release-apk.yml`
(workflow_dispatch)을 트리거 → Release(`test-build-N`)에서 `app-release.apk`를 받는다.
이 빌드는 실 API 키 없이 합성(mock) 데이터로 동작한다.

## 반드시 지킬 것

- **앱 전체에 글자 배율 상한 `kMaxTextScale`(1.5)이 걸려 있다**(`app/app.dart`의
  `clampAppTextScale`을 `MaterialApp.builder`에 넘긴다). 시스템 글자 크기를
  키우면 값을 촘촘히 담는 화면(상세 예보 표·홈 카드·설정)에서 글자가 겹치고
  잘려 오히려 못 읽는다(바다윈디 실사용자 제보로 확인된 문제). **화면마다
  쫓아다니지 말고 여기서 막는다.** 사용자 접근성 설정을 일부 무시하는 대가가
  있으니 값을 함부로 낮추지 말 것. **테스트 하네스도 같은 `clampAppTextScale`을
  써야** 실제와 같은 조건이 된다.
- **작은 아이콘 + 짧은 글자를 담는 촘촘한 칸은 1.3까지만**
  (`core/widgets/compact_text_scale.dart`의 `kCompactMaxTextScale`·
  `CompactTextScale`). 본문은 1.5로 시원하게 두고 **폭이 고정된 작은 칸만 한 번
  더 눌러 둔다**(사용자 요구). 현재 적용된 곳: 날씨 화면 24시간 예보 카드(폭
  58px), 홈 날짜 띠 칩(폭 52px), 홈 라운드 컨디션 셀(일출·일몰·자외선·습도).
  이 칸들은 **높이도 배율만큼 늘려** 세로로도 넘치지 않게 한다(고정 높이로
  두면 칸을 뚫는다).
  **아무 데나 쓰면 안 된다** — 세로로 늘어날 수 있는 본문·표·설정은 앱 상한에
  맡기고 레이아웃을 유연하게(`Expanded`/`Flexible`/줄바꿈) 고치는 쪽이 맞다
  (예: 홈 라운딩 지수 카드는 배율을 누르지 않고 `Expanded`로 고쳤다).
- **레이아웃을 건드리면 `test/features/text_scale_layout_test.dart`를 함께
  돌린다** — 글자 배율 1.0~2.0 × 화면 크기 3종으로 여섯 화면을 그려 오버플로를
  잡는다(상한 덕분에 실제 적용 배율은 최대 1.5다). **검사 화면 크기를 줄이지
  말 것** — 겹침은 특정 조합에서만 난다. 실제로 이 검사를 처음 돌렸을 때
  360×640·**배율 1.0**에서도 홈 라운드 컨디션 카드가 47px 넘치고 있었다(큰
  글자와 무관한 기존 버그).
- **API 키 커밋 금지**: `--dart-define=DATA_GO_KR_API_KEY=...`로만 주입
  (`core/config/env.dart`). Open-Meteo는 키 불필요. 키가 없으면 자동 mock 모드.
- **광고는 부가 기능이라 절대 앱을 막지 않는다**
  (`core/widgets/ad_placeholder.dart`): 배너 로드에 실패하거나 광고가 꺼져
  있으면 **같은 높이의 앱 소개 박스**로 조용히 대체된다 — 이 폴백을 없애면
  광고가 없을 때 레이아웃에 빈 칸이 생긴다. 배너 자리는 **홈·날씨·설정 세
  곳**이고 `AdSlot`으로 구분해 화면마다 다른 광고 단위를 쓸 수 있다(홈용만
  주입하면 나머지는 홈용으로 폴백한다). 세 화면 모두 `AdBannerBar`로 본문을
  감싸 **본문 높이가 배너만큼 줄어든다**(`Scaffold.bottomNavigationBar`에
  넣지 않는다 — 앱 셸의 하단 탭바와 자리를 다툰다).
  광고 ID는 `Env.admob*BannerAdUnitId`(dart-define)와 Gradle 환경변수
  `ADMOB_APP_ID`(AndroidManifest 플레이스홀더)로 **빌드 때 주입**하고, 둘 다
  기본값이 구글 공식 **테스트 ID**라 설정 없이 빌드해도 실 수익 계정에 무효
  트래픽이 잡히지 않는다. 실 ID는 저장소에 커밋하지 않는다.
  **위젯 테스트가 광고 플랫폼 채널을 건드리면 안 되므로** `adsRuntimeEnabled`
  기본값은 false이고 `main()`에서만 켠다 — 테스트에서 이 값을 켜지 말 것.
  `main()`은 SDK 초기화를 **await하지 않는다**(`adsReady`) — 기다리면 광고가
  느린 기기에서 첫 프레임이 몇 초씩 밀린다.
- **바람나침판의 방위 계산은 직접 한다**(`core/sensors/heading_math.dart`):
  가속도계+자력계 원값으로 Android `getRotationMatrix`와 같은 회전행렬을
  만들어 방위각을 뽑는다(`flutter_compass`는 관리가 멈춘 지 오래다).
  **순수 함수라 플러그인 없이 테스트된다** — 값을 바꾸면
  `test/core/heading_math_test.dart`(네 방위·기울임·되감김)를 함께 돌린다.
  지켜야 할 세 가지:
  - **자북이 아니라 진북으로 보정한다**(`magneticDeclinationDeg`). 보정을
    빼면 화면의 "북"이 실제 북에서 8~9도 어긋난다. 한반도 자편각을 위·경도
    1차식으로 근사한 것이고(서울·인천·부산 WMM 값으로 맞춤, 오차 1도 안쪽),
    한반도 밖에서 값이 튀지 않게 범위를 제한한다.
  - **각도를 단순 평균하지 말 것**(`smoothAngleDeg`). 359°→1°에서 바늘이 한
    바퀴 휙 돌아간다. sin/cos로 풀어 섞은 뒤 되돌린다.
  - **나침반 화면만 세로로 고정한다**(`SystemChrome.setPreferredOrientations`,
    `dispose`에서 되돌림). 방위각 계산이 "화면 위쪽 = 기기 +y축"을 전제로 해서,
    화면이 가로로 돌면 나침반이 90도 틀어진다.
  동서남북 좌표는 `compassPointAt`(공개 함수)이 잡는다 — 원판을 통째로
  `Transform.rotate` 하지 않는 이유는 눈금·화살표는 함께 돌리되 **글자만
  똑바로 세워야** 하기 때문이다(함께 돌리면 남쪽을 볼 때 글자가 뒤집힌다).
  **위치 조회에는 반드시 시간 제한을 건다** — 없으면 실내 첫 측위처럼 위치
  서비스가 응답하지 않을 때 "확인하는 중…"에서 영영 안 벗어난다(테스트가
  이 상태를 재현한다).
- **Repository는 항상 실API → 캐싱 → 폴백(합성 데이터) 체인**으로 조립한다
  (`core/network/data_go_kr.dart`의 공용 파서 재사용). 새 데이터 소스도 이 패턴을 따른다.
- **골프장 목록은 생성된 Dart const**(`features/golf/data/golf_courses_data.dart`,
  현재 **531곳** 문화체육관광부_전국 골프장 현황 15118920 기반). 이 목록이 위치
  피커·검색·지도 마커·날씨 대상을 모두 정의한다(`sample_locations.dart`가
  `GolfCourse.toLocation()`으로 범용 `SeaLocation`으로 변환해 공유).
  재생성 도구 2개:
  - `tool/geocode_golf.py <golf.csv>` — 현재 데이터 생성에 쓴 도구. **좌표가 없는
    원본 CSV**(이름·주소·홀·구분)를 받아 내장 시/군/구 중심좌표 + 소재지 기반
    결정적 지터로 좌표를 만든다. 온라인 지오코더가 이 환경에서 전부 차단돼 쓴 방식이라
    좌표는 **군 단위 근사치**다(바람 격자가 성글어 예보엔 충분, 마커도 올바른 시군구).
    정밀 좌표가 생기면(키 있는 Kakao/VWorld 지오코딩) 이 도구를 대체·갱신한다.
  - `tool/gen_golf_courses.py <csv|json>` — **좌표가 포함된** CSV나 odcloud API JSON을
    받아 그대로 굽는 도구(위경도 컬럼 자동 인식). 향후 좌표 포함 소스가 생기면 이걸 쓴다.
  - id는 `gc_<md5(이름+주소)[:8]>`로 안정적·고유. **원본 CSV/인증키는 커밋 금지**.
- **Ticker가 있는 화면(WeatherScreen/Windy)을 테스트할 때 `pumpAndSettle()` 쓰지
  말 것** — 파티클 애니메이션 때문에 멈추지 않는다. `pump()`로 프레임을 지정해 진행한다.
- **`app/app.dart`의 `IndexedStack`에 새 탭을 추가하면 `TickerMode(enabled:
  현재탭)`로 감싸야 한다** — 안 그러면 비활성 탭의 Ticker가 계속 돌아 다른 탭
  위젯 테스트가 멈춘다.
- **지도 바람장은 서버 파일 우선, 단 골프윈디는 자체 수집을 두지 않는다**
  (`features/weather/.../github_wind_field_repository.dart`): `Env.windDataUrl`
  기본값이 **바다윈디(BadaMobile)의 공개 데이터 저장소**
  (`bisan74-lab/badawindy-data`)의 `wind-data` 롤링 릴리스 `wind_field.json.gz`를
  가리킨다. 바다윈디의 GitHub Actions 크론(그 저장소의 `tool/fetch_wind.py`)이
  Open-Meteo에서 격자(적응형 64×66≈4224점, 핵심 해역은 더 촘촘)를 배치로 받아
  주기적으로 올려 둔다. 골프윈디의 지도 bbox·격자 포맷이 바다윈디와 완전히
  같아서(2026-08 재동기화) 같은 파일을 그대로 써도 정확히 맞고, 골프윈디가
  똑같은 데이터를 Open-Meteo에 또 요청하면 순수 낭비이자 호출 한도 이중
  소모라 **골프윈디만의 fetch_wind.py·wind-data.yml 크론은 의도적으로 두지
  않는다**(2026-08 재점검 결론). 파일을 못 받으면(네트워크 실패 등) 앱이
  Open-Meteo 직접 호출→캐시→합성 순으로 자동 폴백한다. 파일 포맷이 바뀌면
  바다윈디 쪽 `fetch_wind.py`에 맞춰 `parseWindFieldFile`(및 그 테스트)을
  함께 갱신해야 한다 — 두 저장소가 분리돼 있으므로 바다윈디의 포맷 변경을
  놓치지 않도록 주의(재동기화 가이드 참고).
- 바람 지도(`features/weather/presentation/`)의 `mapViewBounds`
  (`widgets/map_projection.dart`)와 `OpenMeteoWindFieldRepository`의 격자 범위는
  **같은 bbox**(위 18~57, 경 108~148)를 써야 히트맵이 뷰를 채운다. 범위를 바꾸면
  `country_borders_data.dart`도 같은 bbox로 다시 뽑아야 한다(`tool/gen_coast.py`,
  Natural Earth 10m). 해안선(`CoastlinePainter`)·도시 라벨(`MapCityLabelLayer`)·
  골프장 마커(`GolfMarkerLayer`)는 **모두 실제 WGS84 좌표**를 쓰고 경도 보정
  `kMapLonShift`는 **0**이어야 서로 정확히 겹친다(바꾸면 세 레이어 모두 같은 값).
- **탭은 실제로 열기 전까지 빌드하지 않는다**(`app/app.dart`의 `_visited`
  집합). `IndexedStack`은 기본적으로 자식을 전부 즉시 빌드하는데, 그러면
  앱 시작 시 홈과 동시에 Windy 탭의 무거운 바람장(16일치) 요청까지 나가
  대역폭을 다퉈 홈 첫 화면이 10초 넘게 늦어졌다(실측 원인). 새 탭을
  추가해도 이 지연 빌드 패턴을 유지한다.
- **독립적인 네트워크 호출은 순차 대기(await 연쇄) 대신 동시에 시작**한다
  (`Future.wait` 또는 두 Future를 먼저 만들어 두고 나중에 awit). 기상청
  단기예보·초단기예보·초단기실황 3개 호출(`data_go_kr_kma_repository.dart`)과
  land+kma 예보 병합(`kma_weather/presentation/providers.dart`)이 이 패턴을
  쓴다 — 예전엔 순차 대기라 왕복 지연이 그대로 누적됐다.
- **강제 업데이트 게이트**(`core/remote_config/`): `Env.forceUpgradeConfigUrl`이
  가리키는 JSON의 `forceUpgrade`를 true로 바꾸면 앱 재배포 없이 모든 기기에서
  실행이 막히고 업데이트 안내만 뜬다(무료→광고 전환용). **원본은 이 저장소가
  아니라 별도 공개 데이터 저장소 `bisan74-lab/golfwindy-data`의
  `app_gate.json`이다** — 값을 바꾸려면 거기 파일을 갱신한다(`gov_data_mobile`의
  `remote_config/app_gate.json`은 이관 전 원본 기록용일 뿐 앱이 더는 읽지
  않는다). 배포 전 `storeUrl`을 실제 값으로 채운다. 설정을 못 받으면(오프라인
  등) 항상 정상 실행한다 — 이 폴백 규칙은 절대 건드리지 않는다.
