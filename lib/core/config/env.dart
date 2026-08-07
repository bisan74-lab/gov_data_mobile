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
}
