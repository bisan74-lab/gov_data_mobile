import 'package:flutter/material.dart';

import '../../../../core/widgets/compact_text_scale.dart';
import '../wind_compass_screen.dart';
import 'compass_rose.dart';

/// 위젯 테스트에서 이 버튼만 정확히 집기 위한 키.
const windCompassButtonKey = Key('windCompassButton');

/// 홈 화면의 **바람나침판** 진입 버튼(라운딩 지수 카드 위 오른쪽).
///
/// 아이콘만 두면 무슨 버튼인지 알기 어렵다는 제보를 지도 마커에서 이미
/// 받았으므로(`golf_marker_layer.dart` 참고), 여기도 처음부터 아이콘 옆에
/// 글자를 함께 둔다.
class WindCompassButton extends StatelessWidget {
  const WindCompassButton({super.key});

  /// 아이콘 한 변(논리 픽셀). 머티리얼 기본 아이콘(20~24)보다 **크게** 잡는다
  /// (사용자 요구). 나침반 그림은 눈금 링처럼 가는 요소가 많아, 작으면 그냥
  /// 회색 뭉치로 보인다 — 34px이 원판의 8방위 별이 알아보이는 하한이다.
  /// **글자 배율을 따라 키우지 않는다** — [CompactTextScale] 안이라 라벨은
  /// 1.3까지만 커지고, 아이콘까지 함께 키우면 카드 폭을 밀어낸다.
  static const double _iconSize = 34;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 아이콘 + 짧은 라벨이 한 줄에 붙는 작은 칩이라, 앱 상한(1.5)까지
    // 커지면 카드 폭을 밀어낸다. 이런 자리만 1.3으로 한 번 더 누른다.
    return CompactTextScale(
      child: TextButton.icon(
        key: windCompassButtonKey,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const WindCompassScreen()),
        ),
        // 머티리얼 아이콘 대신 **화면과 같은 나침반**을 축소해 넣는다 —
        // 눌렀을 때 나오는 것이 그대로 보이니 무슨 버튼인지 바로 안다.
        icon: SizedBox.square(
          dimension: _iconSize,
          child: CompassRose(color: scheme.primary),
        ),
        label: const Text(
          '바람나침판',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          visualDensity: VisualDensity.standard,
        ),
      ),
    );
  }
}
