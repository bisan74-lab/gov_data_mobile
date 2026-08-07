import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/compact_text_scale.dart';
import '../../golf/data/models/golf_course.dart';
import '../../golf/logic/golf_advice.dart';
import '../../golf/presentation/providers.dart';
import '../../kma_weather/data/models/land_weather.dart';
import '../../kma_weather/presentation/providers.dart';
import '../../locations/presentation/providers.dart';
import '../../locations/presentation/widgets/region_selector_action.dart';
import '../../weather/presentation/widgets/wind_arrow.dart';
import 'widgets/home_date_strip.dart';

/// 홈 화면. 선택된 골프장의 기본 정보, 선택한 날짜의 **라운딩 지수**·**추천
/// 옷차림**, 그리고 티타임대(오전~오후) **시간대별 바람**을 한눈에 보여준다.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  DateTime _date = DateUtils.dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final location = ref.watch(selectedLocationProvider);
    final course = ref.watch(selectedCourseProvider);
    final forecastAsync = ref.watch(weatherForecastProvider(location));
    final today = DateUtils.dateOnly(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('골프윈디'),
        actions: const [RegionSelectorAction()],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Header(
            title: location.name,
            subtitle: course == null
                ? location.region
                : '${course.region} · ${course.type} · ${course.holes}홀',
            date: _date,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: HomeDateStrip(
              date: _date,
              minDate: today,
              maxDate: today.add(const Duration(days: 14)),
              onChanged: (d) => setState(() => _date = d),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            child: forecastAsync.when(
              loading: () => const _LoadingCard(),
              error: (e, _) => _ErrorCard(message: '$e'),
              data: (f) =>
                  _DayContent(course: course, forecast: f, date: _date),
            ),
          ),
        ],
      ),
    );
  }
}

/// 선택한 날짜의 예보에서 라운딩 지수/옷차림/시간대별 바람을 조립.
class _DayContent extends StatelessWidget {
  const _DayContent({
    required this.course,
    required this.forecast,
    required this.date,
  });

  final GolfCourse? course;
  final WeatherForecast forecast;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    // 해당 날짜의 시간별(티타임대 06~18시)만 추린다.
    final hours = forecast.hourly
        .where(
          (h) =>
              DateUtils.isSameDay(h.time, date) &&
              h.time.hour >= 6 &&
              h.time.hour <= 18,
        )
        .toList();

    // 대표값: 정오에 가장 가까운 시간(없으면 예보 현재값).
    final rep = _representative(hours) ?? _fromNow(forecast.now, date);
    final index = roundingIndex(
      tempC: rep.tempC,
      windSpeedMs: rep.windSpeedMs,
      windGustMs: rep.windGustMs,
      precipProbPct: rep.precipProbPct,
    );
    final outfit = outfitAdvice(
      tempC: rep.tempC,
      windSpeedMs: rep.windSpeedMs,
      precipProbPct: rep.precipProbPct,
    );

    // 선택 날짜의 일별 요약(일출/일몰·자외선). 예보 범위 밖이면 null.
    WeatherDay? day;
    for (final d in forecast.daily) {
      if (DateUtils.isSameDay(d.date, date)) {
        day = d;
        break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RoundIndexCard(index: index, rep: rep),
        const SizedBox(height: 12),
        _OutfitCard(text: outfit, tempC: rep.tempC),
        const SizedBox(height: 12),
        _WindTimelineCard(hours: hours),
        const SizedBox(height: 12),
        _RoundConditionCard(day: day, humidityPct: rep.humidityPct),
        if (course != null && course!.address.isNotEmpty) ...[
          const SizedBox(height: 12),
          _CourseInfoCard(course: course!),
        ],
        const SizedBox(height: 12),
        Text(
          '바람·기온은 기상청 단기예보(근일)와 Open-Meteo(중기)를 합쳐 제공합니다.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  WeatherHour? _representative(List<WeatherHour> hours) {
    if (hours.isEmpty) return null;
    final sorted = [...hours]
      ..sort(
        (a, b) => (a.time.hour - 12).abs().compareTo((b.time.hour - 12).abs()),
      );
    return sorted.first;
  }

  WeatherHour _fromNow(WeatherNow now, DateTime date) => WeatherHour(
    time: DateTime(date.year, date.month, date.day, 12),
    tempC: now.tempC,
    weatherCode: now.weatherCode,
    precipProbPct: 0,
    humidityPct: now.humidityPct,
    windSpeedMs: now.windSpeedMs,
    windGustMs: now.windGustMs,
    windDirDeg: now.windDirDeg,
  );
}

/// 라운딩 지수(1~10) + 대표 바람 요약.
class _RoundIndexCard extends StatelessWidget {
  const _RoundIndexCard({required this.index, required this.rep});

  final int index;
  final WeatherHour rep;

  @override
  Widget build(BuildContext context) {
    final color = _indexColor(index);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withValues(alpha: 0.72)],
        ),
      ),
      // 본문 카드라 배율을 누르지 않고(앱 상한 1.5 그대로) 레이아웃을
      // 유연하게 둔다 — 왼쪽 글자 묶음이 [Expanded]로 남는 폭을 갖고,
      // 큰 글자에서는 줄바꿈으로 흡수된다(예전엔 폭이 고정이라 넘쳤다).
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '라운딩 지수',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  '$index/10  ${roundingLabel(index)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${rep.tempC.round()}°  ·  강수 ${rep.precipProbPct}%',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.92)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              WindArrow(
                directionDeg: rep.windDirDeg,
                size: 34,
                color: Colors.white,
              ),
              const SizedBox(height: 2),
              Text(
                compassKo(rep.windDirDeg),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              Text(
                formatWind(rep.windSpeedMs),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '돌풍 ${formatWind(rep.windGustMs)}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Color _indexColor(int index) {
    if (index >= 9) return const Color(0xFF2E7D32);
    if (index >= 7) return const Color(0xFF558B2F);
    if (index >= 5) return const Color(0xFFF9A825);
    if (index >= 3) return const Color(0xFFEF6C00);
    return const Color(0xFFC62828);
  }
}

/// 추천 옷차림.
class _OutfitCard extends StatelessWidget {
  const _OutfitCard({required this.text, required this.tempC});

  final String text;
  final double tempC;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: scheme.primary,
            child: Icon(_outfitIcon(tempC), color: scheme.onPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('추천 옷차림', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 2),
                Text(text, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static IconData _outfitIcon(double tempC) {
    if (tempC >= 23) return Icons.wb_sunny_outlined;
    if (tempC >= 10) return Icons.checkroom;
    return Icons.ac_unit;
  }
}

/// 티타임대(오전~오후) 시간대별 풍향·풍속.
class _WindTimelineCard extends StatelessWidget {
  const _WindTimelineCard({required this.hours});

  final List<WeatherHour> hours;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.air, size: 18, color: scheme.primary),
              const SizedBox(width: 6),
              Text('시간대별 바람', style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 10),
          if (hours.isEmpty)
            Text(
              '해당 날짜의 시간별 예보가 아직 없습니다.',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: hours.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final h = hours[i];
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formatHm(h.time),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      WindArrow(
                        directionDeg: h.windDirDeg,
                        size: 22,
                        color: scheme.primary,
                      ),
                      Text(
                        formatWind(h.windSpeedMs),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        compassKo(h.windDirDeg),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// 라운드 컨디션: 일출·일몰(티오프/막차 참고), 자외선, 습도.
class _RoundConditionCard extends StatelessWidget {
  const _RoundConditionCard({required this.day, required this.humidityPct});

  final WeatherDay? day;
  final int humidityPct;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = <(IconData, String, String)>[
      if (day?.sunrise != null)
        (Icons.wb_twilight, '일출', formatHm(day!.sunrise!)),
      if (day?.sunset != null)
        (Icons.nights_stay_outlined, '일몰', formatHm(day!.sunset!)),
      if (day != null) (Icons.wb_sunny_outlined, '자외선', _uvLabel(day!.uvMax)),
      (Icons.water_drop_outlined, '습도', '$humidityPct%'),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      // 아이콘+값+라벨 네 칸이 한 줄에 나란히 서는 촘촘한 지표라, 앱 상한
      // (1.5)에서는 가로로 넘친다. 이 칸만 1.3으로 한 번 더 누르고
      // ([CompactTextScale]) 각 칸을 [Expanded]로 폭을 나눠 갖게 해,
      // 넘치는 대신 줄바꿈·말줄임으로 흡수되게 한다.
      child: CompactTextScale(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (icon, label, value) in items)
              Expanded(
                child: Column(
                  children: [
                    Icon(icon, size: 20, color: scheme.primary),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _uvLabel(double uv) {
    final level = uv <= 2
        ? '낮음'
        : uv <= 5
        ? '보통'
        : uv <= 7
        ? '높음'
        : uv <= 10
        ? '매우높음'
        : '위험';
    return '${uv.round()} $level';
  }
}

/// 골프장 기본 정보(주소·홀·유형).
class _CourseInfoCard extends StatelessWidget {
  const _CourseInfoCard({required this.course});

  final GolfCourse course;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.golf_course, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.name,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  '${course.address}  ·  ${course.holes}홀  ·  ${course.type}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.date,
  });

  final String title;
  final String subtitle;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isToday = DateUtils.isSameDay(date, DateTime.now());
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, scheme.primaryContainer],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.place, size: 18, color: scheme.onPrimary),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: 2),
          Text(
            isToday
                ? '오늘 ${date.month}/${date.day}'
                : '${date.month}/${date.day} (${weekdayKo(date)})',
            style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.9)),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 120,
    child: Center(child: CircularProgressIndicator()),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '예보를 불러오지 못했습니다.\n$message',
        style: TextStyle(color: scheme.onErrorContainer),
      ),
    );
  }
}
