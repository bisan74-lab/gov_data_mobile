# 골프윈디 (GolfWindy) — 기획서

## 1. 배경 (Context)

data.go.kr(공공데이터포털) 데이터를 활용한 신규 앱. 조사 결과 **골프장 바람 예보**가
① 검증된 시장(국내 골프 인구 약 700만, 연 내장객 4,641만 명), ② BadaMobile(바다윈디)의
코드 자산(공공 API 연동·캐싱·Windy 스타일 바람 지도) 재사용률이 가장 높음, ③ 경쟁앱
(골프웨더·굿샷날씨·케이웨더 골프날씨)이 모두 소규모이고 "바람 특화" 포지션이 비어 있음
— 세 가지 이유로 선정되었다.

핵심 컨셉: **"골프장 단위의 Windy"**. 골퍼가 라운드 전 예약 판단부터 당일 아침까지
반복 확인하는, 골프장별 시간대별 풍향·풍속에 특화된 무료 한국어 앱.

## 2. 경쟁앱 기능 흡수 (모두 포함)

| 경쟁앱 | 핵심 기능 | 본 앱 반영 |
|---|---|---|
| 골프웨더 | 전국 510여 골프장 날씨 + **추천 옷차림** | 홈 탭에 골프장 정보 + 옷차림 추천 |
| 굿샷날씨 | 시간별 기온·강수·바람·습도, 자외선, 일출/일몰 | 날씨 탭 시간대별 표 + 라운딩 지수 |
| 케이웨더 골프날씨 | 골프장별 정밀 예보 | 골프장 좌표 기반 기상청 단기예보 |
| (Windy) | 지도 위 바람 흐름 시각화 | Windy 탭(바다윈디 지도 그대로 + 골프장 마커) |

## 3. 화면 구성 (4 탭: 홈 / 날씨 / Windy / 설정)

BadaMobile의 앱 셸(`IndexedStack` + `TickerMode` + Material3 `NavigationBar`)을 그대로
계승하되 탭을 4개로 재구성한다(물때·낚시 탭 제거).

### 홈 탭
- 상단 그라디언트 헤더: 선택된 골프장 이름·지역·날짜 스트립(±2주)
- **골프장 정보 카드**: 홀 수, 유형(회원제/대중제), 주소
- **추천 옷차림 카드**: 기온·바람·강수 기반 (반팔/긴팔/바람막이/우비/방한 단계)
- **라운딩 지수 카드**(추가 제안): 기온·바람·강수·자외선 종합 10단계 지수
- **시간대별 바람 요약 카드**(추가 제안): 티타임대(오전/오후) 대표 풍향·풍속 화살표
- **일출/일몰**(추가 제안): 라운드 가능 시간대 참고

### 날씨 탭 (바람 특화)
- 기본으로 **선택된 골프장의 날씨만** 표시 (별도 위치 선택 불필요, 홈과 동일 골프장 공유)
- 시간대별 표: **풍향 화살표 + 풍속**(강조) · 기온 · 강수확률 · 습도
- 상단 우측 골프장 선택 액션(`RegionSelectorAction` 계승)

### Windy 탭
- **바다윈디의 지도 방식 그대로**(현재 버전 이식, 이후 업데이트 재이식):
  등거리 투영 + `InteractiveViewer` 팬/줌 + 바람 히트맵 + 파티클 + 해안선/국경 + 주요 도시 라벨
- **모든 골프장이 지도에 마커로 표시**(줌 단계별 노출, 탭 시 해당 골프장 선택→상세)
- 주요 도시 라벨 유지(주변 위치로 골프장 탐색)
- 바다 해양 정보(파고 등)는 비중 축소
- **우측 상단 돋보기 아이콘** → 골프장 이름 검색 → 지도 해당 골프장으로 이동·선택

### 설정 탭
- BadaMobile 설정 화면 계승: 앱 색상 스킨, 밝기 모드, 배경 그래픽, 광고제거(placeholder),
  정책/약관, 버전, 강제 업데이트 게이트(원격 config)

## 4. 데이터 소스

| 데이터 | 출처 | 상태 |
|---|---|---|
| 전국 골프장 목록·주소·홀수 | 문화체육관광부_전국 골프장 현황 (data.go.kr 15118920) | 자산 JSON, 생성툴로 확장 |
| 골프장 좌표(위경도) | 주소 지오코딩 / LX 공간데이터 | 시드 데이터 + 지오코딩 |
| 시간대별 풍향·풍속·기온·강수·습도 | 기상청 단기예보 (VilageFcstInfoService) | BadaMobile 연동 코드 이식 |
| 바람 지도(격자) | Open-Meteo `/v1/forecast` (무료) | BadaMobile 이식 |
| 골프장 이름 검색 | 내장 골프장 데이터 + Open-Meteo 지오코딩(보조) | 이식 |

**골프장 데이터 파이프라인** (`tool/gen_golf_courses.py`, BadaMobile의 `gen_coast.py` 패턴):
data.go.kr에서 로그인 후 받은 CSV → 정제·좌표 매핑 → `assets/golf_courses.json` 생성.
현재는 실좌표 시드 데이터(주요 골프장)를 내장하고, 전체 ~510개는 툴로 확장한다.

## 5. BadaMobile에서 이식하는 모듈

**그대로 복사**: `core/network/data_go_kr.dart`(공용 파서), `core/config/env.dart`,
`core/storage/`(캐시), `core/remote_config/`(강제업데이트), `app/theme.dart`,
Windy 지도 일체(`features/weather/presentation/widgets/*`: map_projection, coastline_painter,
country_borders_data, map_city_labels, wind_heatmap, wind_map_painter, wind_arrow),
`open_meteo_wind_field_repository`, 기상청 단기예보 repo, 지오코딩·위치 피커.

**개조**: 앱 셸(탭 4개), 홈 화면(골프), 날씨 화면(골프장 고정·바람 특화),
지도 화면(골프장 마커 레이어 + 돋보기 검색), 설정 메타(앱명·색상).

**제거**: `features/tide/`, `features/fishing/` 전체 및 참조.

**신규**: `features/golf/`(GolfCourse 모델, 골프장 provider, 옷차림·라운딩지수 로직,
골프장 마커 레이어, 검색 시트).

## 6. 데이터 흐름 규칙 (BadaMobile 계승)

Repository는 항상 **실 API → 캐싱 → 폴백(합성)** 체인. API 키(`DATA_GO_KR_API_KEY`)는
`--dart-define`으로만 주입, 키 없으면 자동 mock 모드. bbox(위 21~54, 경 112~144)는
`mapViewBounds`·wind 격자·해안선 생성에서 동일하게 유지.

## 7. 검증

Flutter 로컬 미설치 → BadaMobile과 동일하게 **GitHub Actions CI**(`ci.yml`)로
`flutter analyze` + `flutter test` 검증, `release-apk.yml`로 실기기 APK 빌드.
