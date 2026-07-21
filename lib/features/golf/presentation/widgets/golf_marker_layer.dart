import 'package:flutter/material.dart';

import '../../../weather/presentation/widgets/map_projection.dart';
import '../../data/models/golf_course.dart';

/// Windy 지도 위에 골프장 마커를 찍는 레이어. 도시 라벨([MapCityLabelLayer])과
/// 같은 카운터-스케일(1/scale, topLeft 피벗) 방식이라 확대해도 마커가 지리
/// 지점에 고정되고 크기가 일정하다. 모든 골프장을 초록 점으로 항상 표시하고,
/// 이름 라벨은 확대(또는 선택) 시 드러난다. 마커를 탭하면 [onTap]으로 알린다.
class GolfMarkerLayer extends StatelessWidget {
  const GolfMarkerLayer({
    super.key,
    required this.projection,
    required this.scale,
    required this.courses,
    required this.selectedId,
    required this.onTap,
  });

  final MapProjection projection;
  final double scale;
  final List<GolfCourse> courses;
  final String? selectedId;
  final void Function(GolfCourse) onTap;

  /// 이름 라벨이 드러나는 시작 배율(rank가 작을수록 먼저 보임).
  static double _labelThreshold(int rank) => switch (rank) {
    1 => 2.2,
    2 => 3.4,
    _ => 5.0,
  };

  @override
  Widget build(BuildContext context) {
    final b = projection.bounds;
    return Stack(
      children: [
        for (final c in courses)
          if (c.longitude >= b.minLon &&
              c.longitude <= b.maxLon &&
              c.latitude >= b.minLat &&
              c.latitude <= b.maxLat)
            Builder(
              builder: (context) {
                final o = projection.project(
                  c.latitude,
                  c.longitude + kMapLonShift,
                );
                final selected = c.id == selectedId;
                final showLabel = selected || scale >= _labelThreshold(c.rank);
                final marker = Container(
                  width: selected ? 12 : 8,
                  height: selected ? 12 : 8,
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF00E676)
                        : const Color(0xFF43A047),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black54, blurRadius: 2),
                    ],
                  ),
                );
                final content = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    marker,
                    if (showLabel) ...[
                      const SizedBox(width: 3),
                      Text(
                        c.name,
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : const Color(0xFFCDEFD4),
                          fontSize: selected ? 12.5 : 11,
                          fontWeight: FontWeight.w700,
                          shadows: const [
                            Shadow(color: Colors.black, blurRadius: 3),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
                return Positioned(
                  left: o.dx,
                  top: o.dy,
                  child: Transform.scale(
                    scale: 1 / scale,
                    alignment: Alignment.topLeft,
                    child: FractionalTranslation(
                      translation: const Offset(0, -0.5),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onTap(c),
                        child: content,
                      ),
                    ),
                  ),
                );
              },
            ),
      ],
    );
  }
}
