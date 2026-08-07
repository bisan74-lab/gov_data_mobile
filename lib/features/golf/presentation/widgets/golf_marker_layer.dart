import 'package:flutter/material.dart';

import '../../../weather/presentation/widgets/map_projection.dart';
import '../../data/models/golf_course.dart';

/// 지도 마커의 상세 예보 버튼 — 위젯 테스트에서 이 버튼만 정확히 집기 위한 키.
/// (상단 바에도 같은 [Icons.insights] 아이콘이 있어 아이콘만으로는 구분되지 않는다.)
const golfMarkerDetailButtonKey = Key('golfMarkerDetailButton');

/// Windy 지도 위에 **현재 선택된 골프장 하나만** 마커로 찍는 레이어.
/// 도시 라벨([MapCityLabelLayer])과 같은 카운터-스케일(1/scale, topLeft 피벗)
/// 방식이라 확대해도 마커가 지리 지점에 고정되고 크기가 일정하다.
///
/// 이름 라벨과, 그 **아래에 붙는 상세 예보 버튼**이 항상 함께 보이며 **둘 다
/// 탭하면 [onTap]**(그 골프장의 상세 예보 진입)이 불린다. 이름만 탭 가능하던
/// 시절엔 탭할 수 있다는 걸 알아채기 어려워 아이콘 버튼을 덧붙였다.
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

  /// 마커(초록 점 + 이름) 또는 그 아래 상세 예보 버튼 탭 시 호출.
  final VoidCallback? onTap;

  /// 이름 행이 앵커(지리 지점) 위아래로 차지하는 절반 높이(카운터-스케일
  /// 적용 전의 자연 좌표계 기준). 이름 행은 `FractionalTranslation(-0.5)`로
  /// 위로 밀려 초록 점의 중심이 정확히 지리 지점에 오는데, 상세 버튼은 그
  /// 아래에 붙어야 하므로 같은 앵커에서 이만큼 내려 그린다.
  ///
  /// 상세 버튼을 이름 행과 한 Column으로 묶지 않고 **따로 그리는 이유**: 한
  /// 덩어리로 묶으면 전체 높이가 커져 `-0.5` 이동량이 함께 늘고, 그만큼 초록
  /// 점이 지리 지점보다 위로 밀려 마커가 실제 위치와 어긋난다.
  static const double _nameRowHalfHeight = 15;

  /// 상세 버튼을 이름 글자 시작 위치에 맞추는 들여쓰기(점 12 + 간격 4 + 여백 2).
  static const double _detailButtonIndent = 18;

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
        // 이름 행(초록 점 + 골프장명). 탭하면 상세 예보 — 기존 동작 그대로다.
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
        // 이름 바로 아래 상세 예보 버튼. 같은 앵커에서 이름 행 높이만큼만
        // 내려 그려, 초록 점의 지리 위치는 그대로 유지된다.
        Positioned(
          left: o.dx,
          top: o.dy,
          child: Transform.scale(
            scale: 1 / scale,
            alignment: Alignment.topLeft,
            child: Transform.translate(
              offset: const Offset(_detailButtonIndent, _nameRowHalfHeight),
              child: GestureDetector(
                key: golfMarkerDetailButtonKey,
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xE6194D2B),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black54, blurRadius: 3),
                    ],
                  ),
                  child: const Icon(
                    Icons.insights,
                    size: 13,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
