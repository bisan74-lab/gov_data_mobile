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
  /// 비어 있으면(기본) 앱이 Open-Meteo를 직접 호출해 바람장을 만든다. 나중에
  /// GitHub Actions 크론으로 `wind_field.json.gz`를 릴리스에 올리는 구조를 붙이면
  /// 이 값을 그 릴리스 URL로 채운다(사용자 기기의 Open-Meteo 다지점 호출 회피).
  /// `--dart-define=WIND_DATA_URL=...` 로 재정의 가능.
  static const windDataUrl = String.fromEnvironment('WIND_DATA_URL');

  /// 강제 업데이트 게이트 설정(JSON)을 받아오는 URL.
  ///
  /// 무료 버전 배포 후 광고 버전으로 전환할 때, 이 URL이 가리키는 JSON 파일의
  /// `forceUpgrade`를 true로 바꾸면(앱 재배포 없이) 이미 설치된 모든 기기에서
  /// 앱 실행이 막히고 업데이트 안내만 뜬다 — `core/remote_config/`를 참고.
  /// 배포 전 실제 호스팅 위치(자체 도메인, Gist 등)로 바꿔야 한다.
  /// `--dart-define=FORCE_UPGRADE_CONFIG_URL=...` 로 재정의 가능.
  static const forceUpgradeConfigUrl = String.fromEnvironment(
    'FORCE_UPGRADE_CONFIG_URL',
    defaultValue:
        'https://raw.githubusercontent.com/bisan74-lab/gov_data_mobile/'
        'claude/data-go-kr-mobile-app-cvz6mp/remote_config/app_gate.json',
  );
}
