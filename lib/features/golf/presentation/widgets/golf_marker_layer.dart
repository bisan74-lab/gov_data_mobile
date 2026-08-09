import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/widgets/compact_text_scale.dart';
import '../../../weather/presentation/widgets/map_projection.dart';
import '../../data/models/golf_course.dart';

/// 지도 마커의 상세 예보 버튼 — 위젯 테스트에서 이 버튼만 정확히 집기 위한 키.
/// (상단 바에도 같은 [golfDetailForecastIcon] 아이콘이 있어 아이콘만으로는
/// 구분되지 않는다.)
const golfMarkerDetailButtonKey = Key('golfMarkerDetailButton');

/// 상세 예보 진입을 뜻하는 아이콘. 지도 마커 버튼과 상단 바가 **같은 아이콘**을
/// 쓴다(같은 동작이므로).
///
/// 예전엔 `Icons.insights`(꺾은선 그래프)였는데 "무슨 아이콘인지 모르겠다"는
/// 제보를 받아 바꿨다 — 실제로 열리는 화면이 시간별 예보 **표**라 표 아이콘이
/// 뜻과 맞는다. 지도 마커 버튼에는 아이콘 옆에 "상세 예보" 글자도 함께 넣어
/// 아이콘만으로 짐작하지 않아도 되게 했다.
const IconData golfDetailForecastIcon = Icons.table_chart;

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
    this.showDetailButton = true,
  });

  final MapProjection projection;
  final double scale;

  /// 표시할 골프장(선택된 곳). null이면 아무것도 그리지 않는다.
  final GolfCourse? selected;

  /// 마커(초록 점 + 이름) 또는 그 아래 상세 예보 버튼 탭 시 호출.
  final VoidCallback? onTap;

  /// 이름 아래 "상세 예보" 버튼을 보일지. **상세 예보가 이미 열려 있으면
  /// false**로 넘겨 숨긴다 — 보고 있는 화면으로 또 들어가라고 권하는 꼴이라
  /// 지도만 가린다. 이름 탭은 그대로 열려 있어 동작이 사라지진 않는다.
  final bool showDetailButton;

  /// 이름 라벨 글자 크기·점 지름·세로 여백(이름 행 높이 계산에 쓴다).
  static const double _nameFontSize = 12.5;
  static const double _dotSize = 12;
  static const double _nameVPad = 6;

  /// 이름 행이 앵커(지리 지점) 위아래로 차지하는 **절반 높이**(카운터-스케일
  /// 적용 전의 자연 좌표계 기준). 이름 행은 `FractionalTranslation(-0.5)`로
  /// 위로 밀려 초록 점의 중심이 정확히 지리 지점에 오므로, 행의 아래 끝이
  /// 정확히 이 값이다 — 상세 버튼은 같은 앵커에서 이만큼 내려 그린다.
  ///
  /// **상수로 박으면 안 된다.** 글자 배율이 오르면 이름 행만 길어져서, 고정
  /// 값으로 내려 둔 버튼이 이름 위로 파고든다(배율 2.0에서 실제로 겹치는 걸
  /// 확인했다). 그래서 매번 **실제 글자 높이를 재서** 정한다.
  ///
  /// 재는 스타일도 **칩이 실제로 쓰는 것과 같아야** 한다 — fontSize만 준 맨
  /// TextStyle로 재면 글꼴·줄높이가 달라 실제보다 낮게 나오고 그만큼 겹친다.
  ///
  /// 상세 버튼을 이름 행과 한 Column으로 묶지 않고 **따로 그리는 이유**: 한
  /// 덩어리로 묶으면 전체 높이가 커져 `-0.5` 이동량이 함께 늘고, 그만큼 초록
  /// 점이 지리 지점보다 위로 밀려 마커가 실제 위치와 어긋난다.
  static double _nameRowHalfHeight(BuildContext context) {
    final style = DefaultTextStyle.of(
      context,
    ).style.copyWith(fontSize: _nameFontSize, fontWeight: FontWeight.w700);
    final painter = TextPainter(
      text: TextSpan(text: '가', style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    // Row는 점과 글자 중 큰 쪽 높이를 갖고, 그 위아래로 여백이 붙는다.
    final content = math.max(_dotSize, painter.height);
    return (_nameVPad * 2 + content) / 2;
  }

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
          width: _dotSize,
          height: _dotSize,
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
            fontSize: _nameFontSize,
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
                    vertical: _nameVPad,
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
        // 상세 예보가 이미 열려 있으면 그리지 않는다([showDetailButton]).
        if (showDetailButton)
          Positioned(
            left: o.dx,
            top: o.dy,
            child: Transform.scale(
              scale: 1 / scale,
              alignment: Alignment.topLeft,
              child: Transform.translate(
                offset: Offset(
                  _detailButtonIndent,
                  _nameRowHalfHeight(context),
                ),
                child: GestureDetector(
                  key: golfMarkerDetailButtonKey,
                  behavior: HitTestBehavior.opaque,
                  onTap: onTap,
                  // 아이콘만으로는 무슨 버튼인지 알기 어렵다는 제보를 받아
                  // 글자를 함께 넣었다. 지도 위 작은 칩이라 글자 배율은
                  // [CompactTextScale]로 눌러 둔다(칩이 지도를 덮지 않게).
                  child: CompactTextScale(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xE6194D2B),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: Colors.white, width: 1.2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black54, blurRadius: 3),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            golfDetailForecastIcon,
                            size: 12,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '상세 예보',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
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
