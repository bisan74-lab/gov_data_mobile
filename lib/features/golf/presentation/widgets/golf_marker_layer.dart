import 'package:flutter/material.dart';

import '../../../weather/presentation/widgets/map_projection.dart';
import '../../data/models/golf_course.dart';

/// Windy 지도 위에 **현재 선택된 골프장 하나만** 마커로 찍는 레이어.
/// 도시 라벨([MapCityLabelLayer])과 같은 카운터-스케일(1/scale, topLeft 피벗)
/// 방식이라 확대해도 마커가 지리 지점에 고정되고 크기가 일정하다. 이름 라벨도
/// 항상 함께 보이며, **탭하면 [onTap]**(그 골프장의 상세 예보 진입)이 불린다.
class GolfMarkerLayer extends StatelessWidget {
  const GolfMarkerLayer({
    super.key,
    required this.projection,
    required this.scale,
    required this.selected,
    this.onTap,
  });

  final MapProjection projection;
  final double scale;

  /// 표시할 골프장(선택된 곳). null이면 아무것도 그리지 않는다.
  final GolfCourse? selected;

  /// 마커(초록 점 + 이름) 탭 시 호출 — 상세 예보 진입에 쓴다.
  final VoidCallback? onTap;

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
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                // 탭 타깃이 너무 작지 않도록 여백을 살짝 둔다.
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 2,
                  ),
                  child: content,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
