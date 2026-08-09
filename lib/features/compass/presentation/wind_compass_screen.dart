import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../../core/sensors/heading_math.dart';
import '../../../core/utils/formatters.dart';
import '../../kma_weather/data/models/land_weather.dart';
import '../../kma_weather/presentation/providers.dart';
import '../../locations/data/models/sea_location.dart';
import '../../locations/presentation/providers.dart';
import 'widgets/compass_rose.dart';

/// 화면 하단 설명 문구(사용자 지정). 테스트가 이 문구를 그대로 찾는다.
const windCompassCaption = '실시간 현재위치에 따른 바람방향 나침판';

/// 진북 기준 방위 [bearingDeg]가, 기기가 [headingDeg] 쪽을 향한 화면에서
/// 놓이려면 얼마나 돌려야 하는지(라디안). `Transform.rotate`에 그대로 넣는다.
///
/// **나침반의 핵심**이라 따로 빼서 테스트한다. 원판을 돌리는 각도도
/// `screenRotationRad(0, heading)` — "북이 놓이는 자리"와 같은 값이다.
double screenRotationRad(double bearingDeg, double headingDeg) =>
    (bearingDeg - headingDeg) * math.pi / 180;

/// 나침반 화면 전용 — GPS로 잡은 **현재 위치**.
///
/// 홈·날씨 탭이 쓰는 `selectedLocationProvider`(고른 골프장)와 **일부러
/// 분리한다** — 이 화면은 "지금 내가 서 있는 자리의 바람"을 보여주는 것이
/// 목적이라, 고른 골프장을 따라가면 안 된다.
///
/// `autoDispose`라 화면을 나가면 버려지고, 다시 들어오면 위치를 새로 잡는다.
///
/// **반드시 시간 제한을 건다.** 위치 서비스는 응답 없이 그냥 멈춰 있는
/// 경우가 있는데(실내에서 첫 측위, 플랫폼 채널이 조용한 환경 등), 제한이
/// 없으면 화면이 "확인하는 중…"에서 영영 안 벗어난다. 제한에 걸리면 안내와
/// **다시 시도** 버튼이 뜬다.
final currentGpsLocationProvider = FutureProvider.autoDispose<SeaLocation>(
  (ref) => resolveCurrentLocation().timeout(
    const Duration(seconds: 15),
    onTimeout: () => throw Exception('위치를 잡지 못했습니다. 하늘이 트인 곳에서 다시 시도해 주세요.'),
  ),
);

/// 실시간 바람 나침반. 휴대폰을 수평으로 놓으면 동서남북이 실제 방위에
/// 고정되고, 그 위에 **현재 위치의 바람이 불어오는 방향**이 바깥에서 가운데를
/// 향하는 화살표로 얹힌다.
class WindCompassScreen extends ConsumerStatefulWidget {
  const WindCompassScreen({super.key});

  @override
  ConsumerState<WindCompassScreen> createState() => _WindCompassScreenState();
}

class _WindCompassScreenState extends ConsumerState<WindCompassScreen> {
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<MagnetometerEvent>? _magSub;

  Vec3? _accel;
  Vec3? _mag;

  /// 부드럽게 다듬은 **자북 기준** 방위각. 센서를 아직 못 읽었으면 null.
  double? _magneticHeading;

  /// 마지막으로 읽은 기울기(수평에서 벗어난 각도).
  double _tilt = 0;

  /// 자력계가 아예 없는 기기인지(값이 한 번도 안 온 상태와 구분).
  bool _sensorTimedOut = false;
  Timer? _sensorTimer;

  /// 자기장이 왜곡돼 방위를 믿을 수 없는 상태(주변 금속·자석).
  bool _fieldDistorted = false;

  /// 저역통과 계수. 작을수록 부드럽지만 반응이 느리다.
  ///
  /// **가속도계를 특히 느리게 거른다(0.08).** 여기서 뽑는 건 "아래쪽이
  /// 어디냐"(중력)인데, 손으로 돌리는 동안 생기는 가로 가속도가 그대로 섞이면
  /// 중력 방향이 기울어지고, 그만큼 계산된 북이 흔들린다. 폰을 돌릴 때마다
  /// 동쪽 표시가 조금씩 달라 보이던 원인 중 하나다(2026-08-09 제보).
  /// 중력은 원래 거의 안 변하는 값이라 느리게 걸러도 잃을 게 없다.
  static const double _accelAlpha = 0.08;
  static const double _magAlpha = 0.20;
  static const double _headingAlpha = 0.20;

  /// 이보다 기울면 "수평으로 놓으라"고 안내한다.
  static const double _tiltWarnDeg = 30;

  @override
  void initState() {
    super.initState();
    // **이 화면만 세로로 고정한다.** 방위각 계산은 화면 위쪽이 기기 +y축인
    // 세로 방향임을 전제로 한다. 화면이 가로로 돌아가면 그 전제가 깨져
    // 나침반이 90도 틀어진다(앱 전체는 회전을 막지 않는다).
    unawaited(
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]),
    );
    _accelSub = accelerometerEventStream(
      samplingPeriod: SensorInterval.uiInterval,
    ).listen(_onAccel, onError: (_) => _markSensorUnavailable());
    _magSub = magnetometerEventStream(
      samplingPeriod: SensorInterval.uiInterval,
    ).listen(_onMag, onError: (_) => _markSensorUnavailable());
    // 자력계가 없는 기기(일부 저가형·태블릿)에서는 스트림이 조용히 아무 값도
    // 안 준다. 무한 로딩으로 두지 않고 몇 초 뒤 안내로 넘긴다.
    _sensorTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _magneticHeading == null) _markSensorUnavailable();
    });
  }

  void _markSensorUnavailable() {
    if (mounted && !_sensorTimedOut) setState(() => _sensorTimedOut = true);
  }

  void _onAccel(AccelerometerEvent e) {
    _accel = smoothVec3(_accel, (x: e.x, y: e.y, z: e.z), _accelAlpha);
    _recompute();
  }

  void _onMag(MagnetometerEvent e) {
    final raw = (x: e.x, y: e.y, z: e.z);
    // 왜곡 판정은 **거르기 전 원값**으로 한다 — 걸러 놓으면 순간적으로
    // 자석에 가까워진 것이 평균에 묻혀 안 잡힌다.
    _fieldDistorted = !isFieldPlausible(raw);
    _mag = smoothVec3(_mag, raw, _magAlpha);
    _recompute();
  }

  void _recompute() {
    final a = _accel;
    final m = _mag;
    if (a == null || m == null) return;
    final azimuth = magneticAzimuthDeg(a, m);
    // 방위를 못 구하는 순간(자유낙하·자극 부근)에는 직전 값을 유지한다.
    if (azimuth == null) return;
    final tilt = tiltFromFlatDeg(a);
    final next = smoothAngleDeg(_magneticHeading, azimuth, _headingAlpha);
    if (!mounted) return;
    setState(() {
      _magneticHeading = next;
      _tilt = tilt;
      _sensorTimedOut = false;
    });
  }

  @override
  void dispose() {
    _sensorTimer?.cancel();
    _accelSub?.cancel();
    _magSub?.cancel();
    // 화면을 나가면 회전 제한을 되돌린다.
    unawaited(SystemChrome.setPreferredOrientations(DeviceOrientation.values));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locAsync = ref.watch(currentGpsLocationProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('바람나침판')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: locAsync.when(
                loading: () => const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('현재 위치를 확인하는 중…'),
                    ],
                  ),
                ),
                // 권한 거부·위치 서비스 꺼짐·시간 초과 등. 메시지는
                // resolveCurrentLocation이 한국어로 만들어 던진다.
                error: (e, _) => _LocationError(
                  message: '$e',
                  onRetry: () => ref.invalidate(currentGpsLocationProvider),
                ),
                data: (loc) => _Body(
                  location: loc,
                  magneticHeading: _magneticHeading,
                  tilt: _tilt,
                  tiltWarnDeg: _tiltWarnDeg,
                  sensorUnavailable:
                      _sensorTimedOut && _magneticHeading == null,
                  fieldDistorted: _fieldDistorted,
                ),
              ),
            ),
            // 사용자 지정 설명 문구. **상태와 무관하게 항상 하단에 둔다** —
            // 위치를 잡는 중이든 권한이 없든, 이 화면이 "고른 골프장"이
            // 아니라 **지금 내 위치**의 바람을 보여준다는 걸 알 수 있어야
            // 한다.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                windCompassCaption,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const _AccuracyGuide(),
          ],
        ),
      ),
    );
  }
}

/// 위치가 잡힌 뒤의 본문 — 그 지점의 예보를 받아 나침반에 얹는다.
class _Body extends ConsumerWidget {
  const _Body({
    required this.location,
    required this.magneticHeading,
    required this.tilt,
    required this.tiltWarnDeg,
    required this.sensorUnavailable,
    required this.fieldDistorted,
  });

  final SeaLocation location;
  final double? magneticHeading;
  final double tilt;
  final double tiltWarnDeg;
  final bool sensorUnavailable;
  final bool fieldDistorted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forecastAsync = ref.watch(weatherForecastProvider(location));
    final now = forecastAsync.valueOrNull?.now;

    // 자북 → 진북 보정. 위치를 알아야 자편각을 계산할 수 있으므로 여기서 한다.
    final declination = magneticDeclinationDeg(
      location.latitude,
      location.longitude,
    );
    final trueHeading = magneticHeading == null
        ? null
        : (magneticHeading! + declination + 360) % 360;

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: _CompassDial(
                  headingDeg: trueHeading,
                  windFromDeg: now?.windDirDeg,
                ),
              ),
            ),
          ),
        ),
        _Readout(
          now: now,
          loading: forecastAsync.isLoading,
          failed: forecastAsync.hasError,
        ),
        _Notice(
          sensorUnavailable: sensorUnavailable,
          heading: magneticHeading,
          tilt: tilt,
          tiltWarnDeg: tiltWarnDeg,
          fieldDistorted: fieldDistorted,
        ),
        // 설명 문구는 [WindCompassScreen]이 상태와 무관하게 하단에 깐다.
      ],
    );
  }
}

/// 나침반 원판. [headingDeg]가 null이면(센서 대기) 북쪽을 위로 둔 채 그린다.
class _CompassDial extends StatelessWidget {
  const _CompassDial({required this.headingDeg, required this.windFromDeg});

  /// 기기 위쪽이 가리키는 **진북 기준** 방위. 원판을 이만큼 반대로 돌린다.
  final double? headingDeg;

  /// 바람이 **불어오는** 방향(기상 관례, 진북 기준). null이면 화살표를 뺀다.
  final double? windFromDeg;

  @override
  Widget build(BuildContext context) {
    final heading = headingDeg ?? 0;
    final from = windFromDeg;
    return Stack(
      fit: StackFit.expand,
      children: [
        // 원판은 **통째로** 돈다 — 참고 이미지의 짜임새를 그대로 살린다.
        // 도는 각도는 "북이 화면에서 놓이는 자리"와 같다.
        Transform.rotate(
          angle: screenRotationRad(0, heading),
          child: const CompassRose(),
        ),
        // 바람이 불어오는 방향. 지리 방위라 원판과 같은 기준으로 돈다.
        if (from != null)
          Transform.rotate(
            angle: screenRotationRad(from, heading),
            child: const WindArrowOverlay(),
          ),
        // **가운데에 숫자를 얹지 않는다.** 원판 그림(별·눈금)이 배경이라
        // 글자가 묻혀 잘 안 읽혔다(사용자 요구로 삭제). 같은 값은 원판
        // 아래 [_Readout]에 깔끔한 배경으로 이미 나온다.
      ],
    );
  }
}

/// 나침반 아래 숫자 요약(풍향·풍속·돌풍).
class _Readout extends StatelessWidget {
  const _Readout({
    required this.now,
    required this.loading,
    required this.failed,
  });

  final WeatherNow? now;
  final bool loading;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (now == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          loading ? '현재 위치의 바람을 불러오는 중…' : '바람 정보를 불러오지 못했습니다.',
          style: TextStyle(
            color: failed ? scheme.error : scheme.onSurfaceVariant,
          ),
        ),
      );
    }
    final items = <(String, String)>[
      ('풍향', '${compassKo(now!.windDirDeg)}풍'),
      ('풍속', formatWind(now!.windSpeedMs)),
      ('돌풍', formatWind(now!.windGustMs)),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          for (final (label, value) in items)
            Expanded(
              child: Column(
                children: [
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 화면 맨 아래 **나침판 정확도** 안내.
///
/// 휴대폰 나침반은 원래 오차가 있고, 특히 돌리는 동안·돌린 직후 값이
/// 흔들린다. 무엇을 하면 되는지 화면에서 바로 알려 준다(사용자 요구).
///
/// **짧게 유지할 것.** 처음엔 다섯 줄이었는데 "그대로 해도 잘 안 맞기도
/// 하니 간단하게만" 이라는 제보를 받아 세 줄로 줄였다. 해 뜨는 방향과
/// 대조하라는 항목은 실제로 잘 안 맞아 뺐다.
///
/// 접었다 펴는 형태인 이유: 늘 펼쳐 두면 나침반 원판이 그만큼 작아진다.
class _AccuracyGuide extends StatelessWidget {
  const _AccuracyGuide();

  static const _steps = <(IconData, String)>[
    (Icons.stay_current_portrait, '휴대폰을 수평으로 놓습니다.'),
    (Icons.gesture, '허공에 8자를 2번 그립니다.'),
    (Icons.hourglass_bottom, '수평으로 2~3초 기다린 뒤 확인합니다.'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Theme(
      // ExpansionTile의 기본 구분선을 없애 하단이 깔끔하게 보이게 한다.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        dense: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        leading: Icon(Icons.help_outline, size: 20, color: scheme.primary),
        title: Text('나침판 정확도', style: Theme.of(context).textTheme.labelLarge),
        children: [
          for (final (icon, text) in _steps)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 16, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      text,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          // 오차가 남는다는 사실은 남겨 둔다 — 이걸 빼면 표시된 방향을
          // 실제보다 정확한 것으로 믿게 된다.
          Text(
            '휴대폰 나침반은 이렇게 해도 5~10도쯤 오차가 남습니다.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// 센서 상태 안내(자력계 없음 / 자기장 왜곡 / 기울어짐 / 대기 중).
class _Notice extends StatelessWidget {
  const _Notice({
    required this.sensorUnavailable,
    required this.heading,
    required this.tilt,
    required this.tiltWarnDeg,
    required this.fieldDistorted,
  });

  final bool sensorUnavailable;
  final double? heading;
  final double tilt;
  final double tiltWarnDeg;
  final bool fieldDistorted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final String? text;
    if (sensorUnavailable) {
      text = '이 기기에는 지자기 센서가 없어 방위를 표시할 수 없습니다.';
    } else if (heading == null) {
      text = '방위를 잡는 중…';
    } else if (fieldDistorted) {
      // 자기장 세기가 지구 자기장 범위를 벗어났다 = 가까이에 금속·자석이
      // 있다. 이때 방위각은 계산은 되지만 값 자체를 믿으면 안 된다.
      text = '주변 금속·자석 때문에 방위가 정확하지 않습니다. 자리를 옮겨 보세요.';
    } else if (tilt > tiltWarnDeg) {
      text = '휴대폰을 바닥과 나란히 수평으로 놓아 주세요.';
    } else {
      text = null;
    }
    if (text == null) return const SizedBox(height: 8);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: scheme.error),
      ),
    );
  }
}

class _LocationError extends StatelessWidget {
  const _LocationError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Centered(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off, size: 40, color: scheme.error),
            const SizedBox(height: 12),
            Text(
              '현재 위치를 확인할 수 없습니다.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ),
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(child: child);
}
