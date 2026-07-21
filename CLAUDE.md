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
  티타임대 **시간대별 바람** + **라운드 컨디션 카드**(일출·일몰·자외선·습도)
- **날씨**: 선택 골프장의 시간별/일별 예보(시간별 카드에 풍향·풍속 강조)
- **Windy**: 바람 지도(BadaMobile 이식) + 전국 골프장 마커(`GolfMarkerLayer`) +
  주요 도시 라벨 + 우측 레일 **돋보기 검색**(`golf_search_sheet.dart`)
- **설정**: 색상 스킨(기본 페어웨이 그린)·밝기·배경·정책·강제 업데이트 게이트

홈·날씨·Windy는 공용 `selectedLocationProvider`(선택 골프장)를 따른다.
추천 로직(라운딩 지수·옷차림)은 `features/golf/logic/golf_advice.dart`(순수 함수, 테스트 대상).

## 진행 현황 (2026-07 기준)

브랜치 `claude/data-go-kr-mobile-app-cvz6mp`에서 개발. **완료**: 4탭 셸, 홈/날씨/Windy/
설정, Windy 지도 BadaMobile 최신 재동기화(몰입형 UI·16일·bbox 18~57/108~148),
기상청 **단기예보+초단기예보+초단기실황** 병합 연동(우선순위: 실황>초단기예보>단기예보,
`data_go_kr_kma_repository.dart`), 풍향(VEC) 반영, 전국 골프장 **실데이터 531곳**.
`flutter analyze` 0 · `flutter test` 통과 상태 유지.

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

- **API 키 커밋 금지**: `--dart-define=DATA_GO_KR_API_KEY=...`로만 주입
  (`core/config/env.dart`). Open-Meteo는 키 불필요. 키가 없으면 자동 mock 모드.
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
- 바람 지도(`features/weather/presentation/`)의 `mapViewBounds`
  (`widgets/map_projection.dart`)와 `OpenMeteoWindFieldRepository`의 격자 범위는
  **같은 bbox**(위 18~57, 경 108~148)를 써야 히트맵이 뷰를 채운다. 범위를 바꾸면
  `country_borders_data.dart`도 같은 bbox로 다시 뽑아야 한다(`tool/gen_coast.py`,
  Natural Earth 10m). 해안선(`CoastlinePainter`)·도시 라벨(`MapCityLabelLayer`)·
  골프장 마커(`GolfMarkerLayer`)는 **모두 실제 WGS84 좌표**를 쓰고 경도 보정
  `kMapLonShift`는 **0**이어야 서로 정확히 겹친다(바꾸면 세 레이어 모두 같은 값).
- **강제 업데이트 게이트**(`core/remote_config/`): `remote_config/app_gate.json`의
  `forceUpgrade`를 true로 바꾸면 앱 재배포 없이 모든 기기에서 실행이 막히고 업데이트
  안내만 뜬다(무료→광고 전환용). 배포 전 `Env.forceUpgradeConfigUrl`과
  `app_gate.json`의 `storeUrl`을 실제 값으로 채운다. 설정을 못 받으면(오프라인 등)
  항상 정상 실행한다 — 이 폴백 규칙은 절대 건드리지 않는다.
