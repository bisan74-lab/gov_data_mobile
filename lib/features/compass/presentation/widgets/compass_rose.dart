import 'package:flutter/material.dart';

/// 나침반 원판 이미지 경로. 원본(`나침판.png`)의 **흰 배경을 걷어 내고 알파
/// 마스크로 바꾼 것**이라, 흰 픽셀은 투명하고 검은 선일수록 불투명하다.
/// 그래서 [Image.asset]의 `color`로 테마 색을 입히면 밝은 테마에선 검은 선,
/// 어두운 테마에선 흰 선으로 **한 장이 양쪽 다 처리한다**.
///
/// 원본이 505×499라 정사각형(505×505)으로 패딩했다 — **원판 중심이 위젯
/// 중심과 어긋나면 회전할 때 나침반이 비틀거린다.**
const compassRoseAsset = 'assets/compass/compass_rose.png';

/// 바람 화살표 이미지 경로. 원본(`화살표.png`)의 흰 배경을 걷어 내되 파란색은
/// 그대로 살렸다(단순히 "흰색 지우기"로 하면 경계에 흰 테두리가 남아, 흰
/// 바탕에 섞인 것을 역산해 원래 색을 복원했다).
///
/// 원본은 **왼쪽**을 가리키는데, 나침반에서는 바깥에서 가운데로 꽂혀야 하므로
/// **아래쪽**을 향하도록 90도 돌려 저장했다. 그래서 이 이미지를 그대로 두면
/// 화살표가 12시 방향에서 중심을 향한다.
const windArrowAsset = 'assets/compass/wind_arrow.png';

/// 화살표 원본의 가로세로비(45 ÷ 240). 이 비율을 지켜야 원본 모양이 안 눌린다.
const _windArrowAspect = 45 / 240;

/// 나침반 원판. **원판째 회전시켜 쓴다**(`Transform.rotate`) — 별·눈금·글자가
/// 한 벌로 맞물린 그림이라 요소를 따로 돌릴 수 없다. 그래서 남쪽을 볼 때 S
/// 글자가 뒤집히는데, 이는 실제 자침 나침반의 카드가 도는 방식과 같다.
/// 방위를 글자로 읽어야 할 때를 위해 화면 아래에 한글 풍향 표시를 따로 둔다.
class CompassRose extends StatelessWidget {
  const CompassRose({super.key, this.color});

  /// 선의 색. 생략하면 테마의 `onSurface`(밝은 테마=검정, 어두운 테마=흰색).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      compassRoseAsset,
      color: color ?? Theme.of(context).colorScheme.onSurface,
      fit: BoxFit.contain,
      // 축소할 때 눈금 선이 자글거리지 않게 한다.
      filterQuality: FilterQuality.medium,
    );
  }
}

/// 바깥에서 가운데를 향해 꽂히는 바람 화살표. 12시 방향으로 그려지므로,
/// 지리 방위에 맞추는 회전은 바깥에서 `Transform.rotate`로 준다.
///
/// 위치·크기는 원판 지름에 대한 비율로 잡는다 — 반지름의 **90%에서 22%까지**
/// 뻗어, 바깥 눈금은 가리지 않으면서 가운데 숫자도 침범하지 않는다.
class WindArrowOverlay extends StatelessWidget {
  const WindArrowOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: const Alignment(0, -0.85),
      child: FractionallySizedBox(
        heightFactor: 0.34,
        child: AspectRatio(
          aspectRatio: _windArrowAspect,
          child: Image.asset(
            windArrowAsset,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }
}
