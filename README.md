# 골프윈디 (GolfWindy)

**전국 골프장의 날짜·시간대별 바람·날씨 예보 — "골프장 단위의 Windy"**

라운드 전 예약 판단부터 당일 아침까지, 골프장별 풍향·풍속에 특화된 무료 한국어 앱.
공공데이터포털(data.go.kr) 기상청 단기예보와 Open-Meteo를 결합해 제공합니다.

## 주요 기능

- **홈**: 선택 골프장 정보 + 날짜별 라운딩 지수 + 추천 옷차림 + 티타임대 시간대별 바람
- **날씨**: 선택 골프장의 시간별/일별 날씨(바람 강조, 자외선·습도·강수 등 상세)
- **Windy**: 바람 히트맵·흐름선 지도 위에 전국 골프장 마커 + 주요 도시 + 골프장 검색
- **설정**: 색상 테마, 밝기, 배경, 이용약관, 강제 업데이트 게이트

## 데이터 소스

- 기상청 단기예보((구)동네예보) — data.go.kr, `--dart-define=DATA_GO_KR_API_KEY=...`
- Open-Meteo Forecast / Air-Quality — 무료, 키 불필요
- 전국 골프장 현황 — 문화체육관광부(data.go.kr 15118920), `tool/gen_golf_courses.py`로 생성

키가 없으면 자동으로 합성(mock) 데이터로 동작합니다.

## 개발

```bash
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=DATA_GO_KR_API_KEY=발급키   # 실데이터
```

설계·기획은 [docs/PLAN.md](docs/PLAN.md), 개발 규칙은 [CLAUDE.md](CLAUDE.md) 참고.
