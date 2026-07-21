/// 라운딩 지수·추천 옷차림 산출(순수 로직 — Flutter 비의존, 테스트 대상).
///
/// 골프에 가장 큰 영향을 주는 **바람**을 최우선으로 반영하고, 강수확률·기온을
/// 보조로 반영해 1~10 지수를 만든다. 옷차림은 기온대(+바람/비 보정)로 정한다.
library;

/// 라운딩 지수(1~10). 10=최적, 1=사실상 불가.
int roundingIndex({
  required double tempC,
  required double windSpeedMs,
  required double windGustMs,
  required int precipProbPct,
}) {
  double score = 10;

  // 바람: 3m/s 초과부터 감점(라운드 체감·볼 흔들림). 돌풍은 8m/s 초과부터 추가 감점.
  if (windSpeedMs > 3) score -= (windSpeedMs - 3) * 0.6;
  if (windGustMs > 8) score -= (windGustMs - 8) * 0.4;

  // 강수확률: 60%면 약 -2.4, 100%면 -4.
  score -= precipProbPct / 100 * 4;

  // 기온: 12~26℃ 쾌적. 벗어날수록 감점.
  if (tempC < 10) score -= (10 - tempC) * 0.25;
  if (tempC > 28) score -= (tempC - 28) * 0.3;

  return score.clamp(1, 10).round();
}

/// 라운딩 지수 한글 등급.
String roundingLabel(int index) {
  if (index >= 9) return '최적';
  if (index >= 7) return '좋음';
  if (index >= 5) return '보통';
  if (index >= 3) return '주의';
  return '불가';
}

/// 추천 옷차림 문장. 기온대 기준 + 강한 바람/높은 강수확률 보정.
String outfitAdvice({
  required double tempC,
  required double windSpeedMs,
  required int precipProbPct,
}) {
  final String base;
  if (tempC >= 28) {
    base = '반팔·반바지, 자외선 차단(모자·선크림) 필수';
  } else if (tempC >= 23) {
    base = '반팔 셔츠에 얇은 바지';
  } else if (tempC >= 17) {
    base = '긴팔 셔츠 또는 얇은 니트';
  } else if (tempC >= 10) {
    base = '긴팔 + 바람막이/조끼';
  } else if (tempC >= 4) {
    base = '방한 이너 + 겉옷, 장갑 권장';
  } else {
    base = '두꺼운 방한복 + 핫팩·방한 장갑';
  }

  final extras = <String>[];
  if (precipProbPct >= 60) {
    extras.add('우비·방수화 준비');
  } else if (precipProbPct >= 40) {
    extras.add('우산·여벌옷 준비');
  }
  if (windSpeedMs >= 7 && tempC < 20) {
    extras.add('바람막이 필수');
  }

  return extras.isEmpty ? base : '$base · ${extras.join(', ')}';
}
