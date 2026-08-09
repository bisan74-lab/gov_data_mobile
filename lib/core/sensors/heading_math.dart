import 'dart:math' as math;

/// 기기 좌표계의 3축 벡터(가속도 m/s², 지자기 µT).
typedef Vec3 = ({double x, double y, double z});

/// 가속도(중력 포함)와 지자기 원값으로 **기기→월드 회전행렬**을 만든다.
/// Android `SensorManager.getRotationMatrix`와 같은 계산이고, 반환은 3×3을
/// 행 우선으로 편 9개 값이다.
///
/// 직접 계산하는 이유: `flutter_compass`는 관리가 멈춘 지 오래고 플랫폼별
/// 동작이 갈린다. 두 원센서만 있으면 방위각은 이 열 줄로 나오고, **순수
/// 함수라 테스트도 된다**(플러그인 없이 값만 넣어 검증할 수 있다).
///
/// 자유낙하 중이거나 지자기 벡터가 중력과 거의 평행하면(자극 부근) 방위를
/// 구할 수 없어 null을 돌려준다 — 호출부는 그때 직전 값을 유지한다.
List<double>? rotationMatrix(Vec3 a, Vec3 m) {
  // H = m × a — 동쪽을 가리키는 축.
  var hx = m.y * a.z - m.z * a.y;
  var hy = m.z * a.x - m.x * a.z;
  var hz = m.x * a.y - m.y * a.x;
  final normH = math.sqrt(hx * hx + hy * hy + hz * hz);
  // 정상 기기에서 이 값은 보통 100을 훌쩍 넘는다. 0.1 미만이면 두 벡터가
  // 거의 평행하다는 뜻이라 방위를 정할 수 없다(Android와 같은 문턱).
  if (normH < 0.1) return null;
  hx /= normH;
  hy /= normH;
  hz /= normH;

  final normA = math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z);
  if (normA == 0) return null;
  final ax = a.x / normA;
  final ay = a.y / normA;
  final az = a.z / normA;

  // M = a × H — 북쪽을 가리키는 축(수평면에 투영된 지자기).
  final mx = ay * hz - az * hy;
  final my = az * hx - ax * hz;
  final mz = ax * hy - ay * hx;

  return [hx, hy, hz, mx, my, mz, ax, ay, az];
}

/// 기기 위쪽(+y축, 세로 모드에서 화면 윗변)이 가리키는 **자북 기준**
/// 방위각(0~360, 시계 방향). 방위를 구할 수 없으면 null.
double? magneticAzimuthDeg(Vec3 accel, Vec3 mag) {
  final r = rotationMatrix(accel, mag);
  if (r == null) return null;
  // Android `getOrientation`의 azimuth = atan2(R[1], R[4]).
  final deg = math.atan2(r[1], r[4]) * 180 / math.pi;
  return (deg + 360) % 360;
}

/// 기기가 **수평(화면이 하늘을 봄)**에서 얼마나 기울었는지(도).
/// 0이면 완전히 눕힌 상태, 90이면 세워 든 상태.
///
/// 나침반은 눕혔을 때가 가장 정확하므로, 이 값이 크면 화면에서 안내한다.
double tiltFromFlatDeg(Vec3 a) {
  final norm = math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z);
  if (norm == 0) return 90;
  final c = (a.z / norm).clamp(-1.0, 1.0);
  return math.acos(c) * 180 / math.pi;
}

/// 한반도 주변의 **자편각**(진북 기준 자북의 편차, 도. 음수 = 서편).
///
/// 휴대폰 자력계가 주는 건 **자북** 기준 방위라, 그대로 쓰면 화면의 "북"이
/// 실제 북에서 8~9도 어긋난다. 정식 계산에는 WMM 계수표가 필요하지만
/// 앱에 싣기엔 과하므로, 한반도 범위에서 **위·경도 1차식으로 근사**한다.
///
/// 기준점(WMM 2025, 2026년 값):
/// 서울(37.57, 126.98) -8.97°, 인천(37.46, 126.71) -8.91°,
/// 부산(35.18, 129.08) -8.41°. 이 세 점을 지나는 평면을 맞춘 것이다.
///
/// **오차는 1도 안쪽**이고, 실제로는 휴대폰 자력계 자체의 오차(주변 금속·
/// 보정 상태에 따라 몇 도)가 훨씬 크다. 한반도 밖 좌표에서 값이 튀지 않도록
/// 범위를 제한한다.
double magneticDeclinationDeg(double lat, double lon) {
  final d = -8.52 - 0.316 * (lat - 36.0) - 0.093 * (lon - 127.5);
  return d.clamp(-11.0, -5.0);
}

/// 각도(도)의 저역통과 필터. 자력계는 값이 튀어서 그대로 그리면 바늘이
/// 떨린다.
///
/// 359°와 1°는 2° 차이인데 숫자로는 358 차이라, **단순 평균을 내면 바늘이
/// 한 바퀴 휙 돌아간다**. 그래서 각도를 sin/cos로 풀어 섞은 뒤 다시 각도로
/// 되돌린다. [previous]가 null이면(첫 값) [next]를 그대로 쓴다.
///
/// [alpha]는 새 값의 반영 비율(0~1). 작을수록 부드럽고 느리다.
double smoothAngleDeg(double? previous, double next, double alpha) {
  if (previous == null) return (next % 360 + 360) % 360;
  const toRad = math.pi / 180;
  final sin =
      math.sin(previous * toRad) * (1 - alpha) + math.sin(next * toRad) * alpha;
  final cos =
      math.cos(previous * toRad) * (1 - alpha) + math.cos(next * toRad) * alpha;
  final deg = math.atan2(sin, cos) * 180 / math.pi;
  return (deg + 360) % 360;
}

/// 벡터의 저역통과 필터(가속도·지자기 원값용).
Vec3 smoothVec3(Vec3? previous, Vec3 next, double alpha) {
  if (previous == null) return next;
  return (
    x: previous.x * (1 - alpha) + next.x * alpha,
    y: previous.y * (1 - alpha) + next.y * alpha,
    z: previous.z * (1 - alpha) + next.z * alpha,
  );
}
