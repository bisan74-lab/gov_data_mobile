import 'package:flutter/material.dart';

import '../../../../core/widgets/compact_text_scale.dart';
import '../wind_compass_screen.dart';

/// 위젯 테스트에서 이 버튼만 정확히 집기 위한 키.
const windCompassButtonKey = Key('windCompassButton');

/// 홈 화면의 **바람나침판** 진입 버튼(라운딩 지수 카드 위 오른쪽).
///
/// 아이콘만 두면 무슨 버튼인지 알기 어렵다는 제보를 지도 마커에서 이미
/// 받았으므로(`golf_marker_layer.dart` 참고), 여기도 처음부터 아이콘 옆에
/// 글자를 함께 둔다.
class WindCompassButton extends StatelessWidget {
  const WindCompassButton({super.key});

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
        icon: const Icon(Icons.explore_outlined, size: 20),
        label: const Text('바람나침판'),
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
