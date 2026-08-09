import 'dart:io' show Platform;

/// 빌드 시 주입되는 환경 값.
///
/// 예: flutter run --dart-define=DATA_GO_KR_API_KEY=발급받은키
/// API 키는 절대 저장소에 커밋하지 않는다.
class Env {
  Env._();

  /// 공공데이터포털(data.go.kr) 일반 인증키.
  ///
  /// 계정 공통 키이므로 활용신청이 승인된 모든 API에 사용된다:
  /// - 바다낚시지수 조회 (승인됨)
  /// - 조석예보 조회 (추가 활용신청 필요)
  static const dataGoKrApiKey = String.fromEnvironment('DATA_GO_KR_API_KEY');

  /// (구) KHOA 바다누리 직접 발급 키. data.go.kr 키와 별도로 쓸 경우에만 주입.
  static const khoaApiKey = String.fromEnvironment(
    'KHOA_API_KEY',
    defaultValue: '',
  );

  /// 실제 API 대신 목 데이터를 사용할지 여부. 키가 없으면 자동으로 목 사용.
  static bool get useMockData => dataGoKrApiKey.isEmpty && khoaApiKey.isEmpty;

  /// 지도용 바람장 격자 데이터(서버가 미리 뽑아 둔 정적 파일) URL.
  ///
  /// **바다윈디(BadaMobile)의 공개 데이터 저장소(`badawindy-data`)를 그대로
  /// 쓴다** — 골프윈디의 지도 bbox(위 18~57, 경 108~148)와 격자 포맷(fmt 3,
  /// 64×66 적응형)이 바다윈디와 완전히 같아서(2026-08 재동기화로 맞춤),
  /// 같은 파일을 그대로 재사용해도 정확히 맞는다. 골프윈디가 별도로 같은
  /// 격자를 Open-Meteo에 다시 요청하면 완전히 같은 데이터를 중복으로
  /// 받아오는 셈이라(호출 낭비·한도 이중 소모), 자체 수집 파이프라인을 두지
  /// 않는다. 파일을 못 받으면(네트워크 실패 등) 앱이 Open-Meteo 직접 호출로
  /// 자동 폴백한다. `--dart-define=WIND_DATA_URL=...` 로 재정의 가능.
  static const windDataUrl = String.fromEnvironment(
    'WIND_DATA_URL',
    defaultValue:
        'https://github.com/bisan74-lab/badawindy-data/releases/'
        'download/wind-data/wind_field.json.gz',
  );

  /// 강제 업데이트 게이트 설정(JSON)을 받아오는 URL.
  ///
  /// 무료 버전 배포 후 광고 버전으로 전환할 때, 이 URL이 가리키는 JSON 파일의
  /// `forceUpgrade`를 true로 바꾸면(앱 재배포 없이) 이미 설치된 모든 기기에서
  /// 앱 실행이 막히고 업데이트 안내만 뜬다 — `core/remote_config/`를 참고.
  ///
  /// **골프윈디 전용 공개 데이터 저장소(`golfwindy-data`)를 가리킨다.**
  /// `gov_data_mobile`(코드 저장소)이 비공개로 전환되면 raw 파일을 앱이
  /// 익명으로 못 받으므로(인증 필요 → 404 → 게이트가 조용히 꺼짐, 앱 자체는
  /// 항상 정상 실행되니 위험하진 않지만 게이트 기능을 못 쓰게 된다),
  /// 이 설정만 별도 공개 저장소에 둔다(바다윈디가 `badawindy-data`를 쓰는
  /// 것과 같은 방식). 원본은 `golfwindy-data`의 `app_gate.json`이고, 값을
  /// 바꾸려면 그 저장소의 파일을 갱신한다(`gov_data_mobile`의
  /// `remote_config/app_gate.json`은 그 저장소로 옮기기 전 원본 기록용으로만
  /// 남겨 둔다). `--dart-define=FORCE_UPGRADE_CONFIG_URL=...` 로 재정의 가능.
  static const forceUpgradeConfigUrl = String.fromEnvironment(
    'FORCE_UPGRADE_CONFIG_URL',
    defaultValue:
        'https://raw.githubusercontent.com/bisan74-lab/golfwindy-data/'
        'main/app_gate.json',
  );

  /// 홈 화면 하단 배너의 AdMob 광고 단위 ID(플랫폼별).
  ///
  /// 기본값은 **구글이 공개한 테스트 광고 단위 ID**다. 그래서 아무 설정 없이
  /// 빌드해도 테스트 광고가 뜨고, 실제 수익 계정에 무효 트래픽이 잡히지
  /// 않는다. 스토어에 올릴 빌드는 반드시 실제 ID를 주입한다:
  /// `--dart-define=ADMOB_BANNER_AD_UNIT_ID=ca-app-pub-XXXX/YYYY`
  ///
  /// 빈 문자열을 주입하면 광고를 아예 로드하지 않고 앱 소개 박스만 보여준다
  /// (광고 없는 버전을 내보낼 때 쓴다).
  ///
  /// **AdMob 광고 단위는 플랫폼마다 다르다.** 같은 앱이라도 Android용과 iOS용
  /// 단위를 AdMob에서 따로 만들어야 하고, 서로 바꿔 넣으면 광고가 안 나온다.
  /// 그래서 주입 키도 `..._IOS`로 나누고, iOS에서 값을 안 주면 구글 iOS
  /// **테스트** 단위로 떨어진다(안드로이드 단위로 폴백하지 않는다 — 잘못된
  /// 플랫폼 단위를 쓰면 조용히 광고가 사라진다).
  static const _androidBannerAdUnitId = String.fromEnvironment(
    'ADMOB_BANNER_AD_UNIT_ID',
    defaultValue: 'ca-app-pub-3940256099942544/6300978111',
  );
  static const _iosBannerAdUnitId = String.fromEnvironment(
    'ADMOB_BANNER_AD_UNIT_ID_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/2934735716',
  );

  static String get admobBannerAdUnitId =>
      Platform.isIOS ? _iosBannerAdUnitId : _androidBannerAdUnitId;

  static const _androidWeatherBannerAdUnitId = String.fromEnvironment(
    'ADMOB_WEATHER_BANNER_AD_UNIT_ID',
  );
  static const _iosWeatherBannerAdUnitId = String.fromEnvironment(
    'ADMOB_WEATHER_BANNER_AD_UNIT_ID_IOS',
  );
  static const _androidSettingsBannerAdUnitId = String.fromEnvironment(
    'ADMOB_SETTINGS_BANNER_AD_UNIT_ID',
  );
  static const _iosSettingsBannerAdUnitId = String.fromEnvironment(
    'ADMOB_SETTINGS_BANNER_AD_UNIT_ID_IOS',
  );

  /// 날씨 화면 하단 배너. 주입하지 않으면 [admobBannerAdUnitId]를 그대로 쓴다.
  ///
  /// 화면별로 광고 단위를 나누면 AdMob 리포트에서 어느 자리가 얼마나 버는지
  /// 따로 볼 수 있다. 단위를 하나만 만든 경우에도 설정이 필요 없고, 광고를
  /// 끄려고 [admobBannerAdUnitId]에 빈 값을 주입하면 함께 꺼진다.
  static String get admobWeatherBannerAdUnitId => _orDefault(
    Platform.isIOS ? _iosWeatherBannerAdUnitId : _androidWeatherBannerAdUnitId,
  );

  /// 설정 화면 하단 배너. 주입하지 않으면 [admobBannerAdUnitId]를 그대로 쓴다.
  static String get admobSettingsBannerAdUnitId => _orDefault(
    Platform.isIOS
        ? _iosSettingsBannerAdUnitId
        : _androidSettingsBannerAdUnitId,
  );

  static String _orDefault(String id) => id.isEmpty ? admobBannerAdUnitId : id;
}
