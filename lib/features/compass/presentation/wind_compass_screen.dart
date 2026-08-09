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

/// 화면 하단 설명 문구(사용자 지정). 테스트가 이 문구를 그대로 찾는다.
const windCompassCaption = '실시간 현재위치에 따른 바람방향 나침판';

/// 진북 기준 방위 [bearingDeg]가, 기기가 [headingDeg] 쪽을 향한 화면에서
/// 놓이는 자리 — [center]에서 [radius]만큼 떨어진 점. 화면 위쪽이 0도이고
/// 시계 방향으로 증가한다.
///
/// **나침반의 핵심**이라 따로 빼서 테스트한다. 원판을 통째로
/// `Transform.rotate` 하지 않고 좌표를 직접 잡는 이유는, 눈금·화살표는
/// 원판과 함께 돌리되 **동서남북 글자만 똑바로 세워야** 하기 때문이다
/// (함께 돌리면 남쪽을 볼 때 글자가 뒤집혀 못 읽는다).
Offset compassPointAt(
  Offset center,
  double bearingDeg,
  double headingDeg,
  double radius,
) {
  // 기기가 headingDeg 쪽을 보고 있으므로 그만큼 빼면 화면 각이 된다.
  final a = (bearingDeg - headingDeg) * math.pi / 180;
  return Offset(
    center.dx + radius * math.sin(a),
    center.dy - radius * math.cos(a),
  );
}

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

  /// 방위각 표시용 저역통과 계수. 작을수록 부드럽지만 반응이 느리다.
  static const double _headingAlpha = 0.15;
  static const double _rawAlpha = 0.25;

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
    _accel = smoothVec3(_accel, (x: e.x, y: e.y, z: e.z), _rawAlpha);
    _recompute();
  }

  void _onMag(MagnetometerEvent e) {
    _mag = smoothVec3(_mag, (x: e.x, y: e.y, z: e.z), _rawAlpha);
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
                ),
              ),
            ),
            // 사용자 지정 설명 문구. **상태와 무관하게 항상 하단에 둔다** —
            // 위치를 잡는 중이든 권한이 없든, 이 화면이 "고른 골프장"이
            // 아니라 **지금 내 위치**의 바람을 보여준다는 걸 알 수 있어야
            // 한다.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                windCompassCaption,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
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
  });

  final SeaLocation location;
  final double? magneticHeading;
  final double tilt;
  final double tiltWarnDeg;
  final bool sensorUnavailable;

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
                  windSpeedMs: now?.windSpeedMs,
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
        ),
        // 설명 문구는 [WindCompassScreen]이 상태와 무관하게 하단에 깐다.
      ],
    );
  }
}

/// 나침반 원판. [headingDeg]가 null이면(센서 대기) 북쪽을 위로 둔 채 그린다.
class _CompassDial extends StatelessWidget {
  const _CompassDial({
    required this.headingDeg,
    required this.windFromDeg,
    required this.windSpeedMs,
  });

  /// 기기 위쪽이 가리키는 **진북 기준** 방위. 원판을 이만큼 반대로 돌린다.
  final double? headingDeg;

  /// 바람이 **불어오는** 방향(기상 관례, 진북 기준). null이면 화살표를 뺀다.
  final double? windFromDeg;
  final double? windSpeedMs;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _CompassPainter(
        headingDeg: headingDeg ?? 0,
        windFromDeg: windFromDeg,
        dial: scheme.onSurfaceVariant,
        cardinal: scheme.onSurface,
        north: const Color(0xFFE53935),
        wind: scheme.primary,
        face: scheme.surfaceContainerHighest,
        textScaler: MediaQuery.textScalerOf(context),
      ),
      child: Center(
        // 가운데 숫자는 원판과 함께 돌지 않는다(뒤집히면 못 읽는다).
        child: _CenterReadout(
          windSpeedMs: windSpeedMs,
          windFromDeg: windFromDeg,
        ),
      ),
    );
  }
}

class _CenterReadout extends StatelessWidget {
  const _CenterReadout({required this.windSpeedMs, required this.windFromDeg});

  final double? windSpeedMs;
  final double? windFromDeg;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (windSpeedMs == null || windFromDeg == null) {
      return Text(
        '바람 정보\n확인 중…',
        textAlign: TextAlign.center,
        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${compassKo(windFromDeg!)}풍',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
        ),
        Text(
          formatWind(windSpeedMs!),
          style: TextStyle(
            color: scheme.onSurface,
            fontSize: 26,
            fontWeight: FontWeight.bold,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

class _CompassPainter extends CustomPainter {
  _CompassPainter({
    required this.headingDeg,
    required this.windFromDeg,
    required this.dial,
    required this.cardinal,
    required this.north,
    required this.wind,
    required this.face,
    required this.textScaler,
  });

  final double headingDeg;
  final double? windFromDeg;
  final Color dial;
  final Color cardinal;
  final Color north;
  final Color wind;
  final Color face;
  final TextScaler textScaler;

  Offset _at(Offset center, double bearing, double radius) =>
      compassPointAt(center, bearing, headingDeg, radius);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2;

    canvas.drawCircle(center, r, Paint()..color = face);
    canvas.drawCircle(
      center,
      r - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = dial.withValues(alpha: 0.4),
    );

    // 눈금: 15도마다 짧게, 45도마다 길게.
    for (var b = 0; b < 360; b += 15) {
      final major = b % 45 == 0;
      final inner = r - (major ? 18 : 10);
      canvas.drawLine(
        _at(center, b.toDouble(), inner),
        _at(center, b.toDouble(), r - 3),
        Paint()
          ..strokeWidth = major ? 2.5 : 1.2
          ..color = b == 0 ? north : dial.withValues(alpha: major ? 0.8 : 0.45),
      );
    }

    // 동서남북 글자. **위치는 원판과 함께 돌지만 글자는 항상 똑바로** 세운다
    // — 함께 돌리면 남쪽을 볼 때 글자가 뒤집혀 읽을 수 없다.
    const labels = <(double, String)>[
      (0, '북'),
      (90, '동'),
      (180, '남'),
      (270, '서'),
    ];
    for (final (bearing, text) in labels) {
      final isNorth = bearing == 0;
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: isNorth ? north : cardinal,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout();
      final p = _at(center, bearing, r - 34);
      painter.paint(
        canvas,
        Offset(p.dx - painter.width / 2, p.dy - painter.height / 2),
      );
    }

    _paintWindArrow(canvas, center, r);

    // 기기가 향한 쪽(화면 위)을 알려 주는 고정 표식. 원판이 돌아도 이 표식은
    // 늘 화면 맨 위에 있어, 내가 어느 쪽을 보고 서 있는지 알 수 있다.
    final marker = Path()
      ..moveTo(center.dx, center.dy - r + 2)
      ..lineTo(center.dx - 7, center.dy - r - 10)
      ..lineTo(center.dx + 7, center.dy - r - 10)
      ..close();
    canvas.drawPath(marker, Paint()..color = dial.withValues(alpha: 0.7));
  }

  /// 바람이 **불어오는 쪽에서 가운데를 향해** 꽂히는 화살표.
  /// 사용자 요구: "바깥에서 나침판 방향으로 화살표".
  void _paintWindArrow(Canvas canvas, Offset center, double r) {
    final from = windFromDeg;
    if (from == null) return;

    final tail = _at(center, from, r - 46); // 바깥쪽 시작점
    final head = _at(center, from, r * 0.34); // 가운데 쪽 화살촉 끝
    final paint = Paint()
      ..color = wind
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    // 화살촉이 차지할 길이만큼 몸통을 짧게 그린다(촉과 겹치면 뭉툭해진다).
    const headLen = 26.0;
    final dir = head - tail;
    final len = dir.distance;
    if (len <= headLen) return;
    final unit = dir / len;
    canvas.drawLine(tail, head - unit * headLen, paint);

    // 삼각형 화살촉.
    final perp = Offset(-unit.dy, unit.dx);
    final base = head - unit * headLen;
    final path = Path()
      ..moveTo(head.dx, head.dy)
      ..lineTo(base.dx + perp.dx * 11, base.dy + perp.dy * 11)
      ..lineTo(base.dx - perp.dx * 11, base.dy - perp.dy * 11)
      ..close();
    canvas.drawPath(path, Paint()..color = wind);
  }

  @override
  bool shouldRepaint(_CompassPainter old) =>
      old.headingDeg != headingDeg ||
      old.windFromDeg != windFromDeg ||
      old.dial != dial ||
      old.wind != wind;
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

/// 센서 상태 안내(자력계 없음 / 기울어짐 / 대기 중).
class _Notice extends StatelessWidget {
  const _Notice({
    required this.sensorUnavailable,
    required this.heading,
    required this.tilt,
    required this.tiltWarnDeg,
  });

  final bool sensorUnavailable;
  final double? heading;
  final double tilt;
  final double tiltWarnDeg;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final String? text;
    if (sensorUnavailable) {
      text = '이 기기에는 지자기 센서가 없어 방위를 표시할 수 없습니다.';
    } else if (heading == null) {
      text = '방위를 잡는 중…';
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
