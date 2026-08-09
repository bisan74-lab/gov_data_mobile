# Play Console 등록 — 골프윈디 고유 값

Play Console에서 물어보는 것 중 **이 앱에만 해당하는 값**을 한자리에 모았다.
등록·심사 화면을 오가며 매번 코드를 뒤지지 않도록 하는 것이 목적이다.

문구(앱 이름·설명)와 심사 양식 답변은 [PLAY_STORE_LISTING.md](PLAY_STORE_LISTING.md)에
있다. 이 문서는 **식별자와 설정값**만 담는다.

> **비밀값은 여기 적지 않는다.** AdMob 실 ID·키스토어 비밀번호·API 키는
> GitHub Secret에만 두고, 여기에는 **Secret 이름**만 적는다.

---

## 앱 식별

| 항목 | 값 | 어디서 오나 |
|---|---|---|
| **패키지명(applicationId)** | `com.golfwindy.golf_windy` | `android/app/build.gradle.kts` |
| **기기 런처 이름** | `골프윈디` | `AndroidManifest.xml`의 `android:label` |
| **Play 스토어 표시 이름** | `골프윈디 - 골프장 바람 날씨` | Play Console 입력 |
| **버전 이름 / 코드** | `0.1.0` / `2` | `pubspec.yaml`의 `version: 0.1.0+2` |
| **개발자 문의 이메일** | `bisan74@gmail.com` | `lib/features/settings/app_info.dart` |

⚠️ **패키지명은 최초 등록 이후 절대 바꿀 수 없다.** 바꾸려면 새 앱으로
등록해야 하고 기존 설치·리뷰·순위가 모두 사라진다.

⚠️ **같은 버전 코드는 두 번 올릴 수 없다.** 제출 전 `pubspec.yaml`의 `+N`을
올린다. `AppInfo.appVersion`은 버전 **이름**과 손으로 맞춰 둔 값이라, 버전
이름을 바꿀 땐 둘을 함께 고친다.

## 빌드 설정

| 항목 | 값 | 근거 |
|---|---|---|
| `minSdk` | **23** (Android 6.0) | Google Mobile Ads SDK 요구. Android 5.x는 설치 대상에서 제외 |
| `targetSdk` / `compileSdk` | **36** (Android 16) | Play가 2026-08-31부터 요구 |
| AGP / Gradle | 8.9.1 / 8.12 | API 36 지원 버전 |
| Flutter | 3.32.5 | 워크플로에 고정 |

## 스토어 분류

| 항목 | 값 |
|---|---|
| 카테고리 | **스포츠** |
| 앱/게임 | **앱** |
| 유료/무료 | **무료** |
| 광고 포함 | **예** (배너, Google AdMob) |
| 인앱 구매 | **아니요** |
| 콘텐츠 등급 | **전체 이용가** (설문 전 항목 아니요) |
| 대상 연령 | 만 13세 이상 |

## URL

| 항목 | 값 |
|---|---|
| 개인정보처리방침 | https://github.com/bisan74-lab/golfwindy-data/blob/main/privacy.md |
| 강제 업데이트 게이트 설정 | https://raw.githubusercontent.com/bisan74-lab/golfwindy-data/main/app_gate.json |

`app_gate.json`의 `storeUrl`은 **Play에 실제로 등록된 뒤** 스토어 링크
(`https://play.google.com/store/apps/details?id=com.golfwindy.golf_windy`)로
채운다.

## 서명

| 항목 | 값 |
|---|---|
| 업로드 키 별칭 | `golfwindy` |
| 인증서 주체 | `CN = nathan jang` |
| Play 앱 서명 | 가입(신규 앱 기본) — 업로드 키를 잃어도 구글이 재설정해 준다 |

키스토어 원본(`golfwindy-upload.jks`)은 저장소에 **없다.** 개발자 로컬에만
있으며 `.gitignore`가 `*.jks`·`key.properties`를 막고 있다.

## GitHub Secret

값은 Play Console이 아니라 저장소 Settings → Secrets and variables → Actions에
있다. **이름만 적는다.**

| Secret | 쓰는 곳 |
|---|---|
| `KEYSTORE_BASE64` | AAB 서명 |
| `KEYSTORE_PASSWORD` | AAB 서명 |
| `KEY_ALIAS` | AAB 서명 |
| `KEY_PASSWORD` | AAB 서명 |
| `ADMOB_APP_ID` | AndroidManifest(Gradle 환경변수) |
| `ADMOB_BANNER_AD_UNIT_ID` | 홈 배너(dart-define) |
| `ADMOB_WEATHER_BANNER_AD_UNIT_ID` | 날씨 배너(선택, 없으면 홈 단위) |
| `ADMOB_SETTINGS_BANNER_AD_UNIT_ID` | 설정 배너(선택, 없으면 홈 단위) |
| `DATA_GO_KR_API_KEY` | 기상청 실데이터 |

## 저장소

| 항목 | 값 |
|---|---|
| 코드 | `bisan74-lab/gov_data_mobile` |
| 개발 브랜치 | `claude/data-go-kr-mobile-app-cvz6mp` |
| 공개 데이터 | `bisan74-lab/golfwindy-data` (개인정보처리방침·게이트 설정) |
| 바람장 데이터 | `bisan74-lab/badawindy-data` (바다윈디와 공유) |

## 빌드 워크플로

| 워크플로 | 만드는 것 | 서명 | 광고 |
|---|---|---|---|
| `release-apk.yml` | 기기 설치용 APK | debug 키 | `ads` 입력: `test`(기본) / `none` / `real` |
| `release-aab.yml` | 스토어 제출용 AAB | 업로드 키 | 실제 광고 고정 |

- 스토어에 올릴 파일은 **AAB만** 쓴다. debug 키로 서명된 APK는 Play가 거부한다.
- 스크린샷은 `ads=none`으로 찍는다(테스트 광고 딱지도, 무효 트래픽도 없다).

---

## 등록 순서

1. Play Console → **앱 만들기** (이름·언어 한국어·앱·무료)
2. **내부 테스트** → 새 버전 만들기 → `release-aab.yml`이 만든 AAB 업로드
   - 처음 업로드 시 **Play 앱 서명** 가입 안내가 나오면 그대로 진행
3. **스토어 등록정보** — [PLAY_STORE_LISTING.md](PLAY_STORE_LISTING.md)의 문구와
   `store/`의 이미지 사용, 스크린샷은 직접 촬영
4. **콘텐츠 등급** 설문 → **데이터 보안** 양식 → **개인정보처리방침 URL**
   (세 항목의 답변은 모두 LISTING 문서에 있다)
5. **광고 포함 여부** = 예
6. 검토 제출

출시가 실제로 노출된 뒤에 `app_gate.json`의 `storeUrl`을 채운다 — **순서를
뒤집으면 안 된다.** 업데이트할 것이 없는 상태로 안내 화면만 뜨게 된다.
