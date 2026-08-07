import 'package:flutter/material.dart';

/// **작은 아이콘 + 짧은 글자를 담는 촘촘한 칸만의 배율 상한(1.3).**
///
/// 앱 전체 상한은 1.5(`kMaxTextScale`)인데, 폭이 고정된 작은 칸(시간별 예보
/// 카드 58px, 홈 날짜 칩, 라운드 컨디션 셀)은 그 배율에서 글자가 칸 밖으로
/// 넘치거나 두 줄로 쪼개져 칸을 뚫는다. 본문 글자는 1.5로 시원하게 두고
/// **아이콘이 붙은 작은 칸만 1.3으로 눌러 둔다**(사용자 요구).
///
/// 아이콘 크기는 원래 글자 배율을 따라가지 않으므로(고정 px) 따로 조정하지
/// 않는다 — 라벨만 눌러도 칸 안 균형이 유지된다.
const double kCompactMaxTextScale = 1.3;

/// [child] 안의 글자 배율을 [kCompactMaxTextScale]로 한 번 더 누른다.
///
/// **아무 데나 쓰면 안 된다** — 사용자의 접근성 설정을 그만큼 더 무시하는
/// 것이라, **크기가 고정된 작은 칸**(가로 스크롤 카드, 날짜 칩, 지표 셀)에만
/// 쓴다. 본문·표·설정처럼 세로로 늘어날 수 있는 곳은 앱 상한(1.5)에 맡기고
/// 레이아웃을 유연하게(`Expanded`/`Flexible`/줄바꿈) 고치는 쪽이 맞다.
class CompactTextScale extends StatelessWidget {
  const CompactTextScale({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: kCompactMaxTextScale,
    child: child,
  );
}
