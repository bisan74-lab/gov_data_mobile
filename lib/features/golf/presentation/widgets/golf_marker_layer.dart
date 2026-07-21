import 'package:flutter/material.dart';

import '../../../weather/presentation/widgets/map_projection.dart';
import '../../data/models/golf_course.dart';

/// Windy 지도 위에 **현재 선택된 골프장 하나만** 마커로 찍는 레이어.
/// 도시 라벨([MapCityLabelLayer])과 같은 카운터-스케일(1/scale, topLeft 피벗)
/// 방식이라 확대해도 마커가 지리 지점에 고정되고 크기가 일정하다. 이름 라벨도
/// 항상 함께 보인다(선택 지역이라 지도가 그 위치로 고정돼 있으므로).
class GolfMarkerLayer extends StatelessWidget {
  const GolfMarkerLayer({
    super.key,
    required this.projection,
    required this.scale,
    required this.selected,
  });

  final MapProjection projection;
  final double scale;

  /// 표시할 골프장(선택된 곳). null이면 아무것도 그리지 않는다.
  final GolfCourse? selected;

  @override
  Widget build(BuildContext context) {
    final c = selected;
    if (c == null) return const SizedBox.shrink();
    final b = projection.bounds;
    if (c.longitude < b.minLon ||
        c.longitude > b.maxLon ||
        c.latitude < b.minLat ||
        c.latitude > b.maxLat) {
      return const SizedBox.shrink();
    }
    final o = projection.project(c.latitude, c.longitude + kMapLonShift);
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: const Color(0xFF00E676),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.4),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 3)],
          ),
        ),
        const SizedBox(width: 4),
        Text(
          c.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            shadows: [Shadow(color: Colors.black, blurRadius: 3)],
          ),
        ),
      ],
    );
    return Stack(
      children: [
        Positioned(
          left: o.dx,
          top: o.dy,
          child: Transform.scale(
            scale: 1 / scale,
            alignment: Alignment.topLeft,
            child: FractionalTranslation(
              translation: const Offset(0, -0.5),
              child: content,
            ),
          ),
        ),
      ],
    );
  }
}
