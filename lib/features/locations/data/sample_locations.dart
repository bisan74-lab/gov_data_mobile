import '../../golf/data/golf_courses_data.dart';
import 'models/sea_location.dart';

/// 앱이 다루는 지점 목록 = 전국 골프장([golfCourses])을 범용 [SeaLocation]으로
/// 변환한 것. 위치 피커·검색·지도 마커·날씨가 모두 이 목록을 공유한다.
/// 골프장 데이터가 갱신되면(생성 툴) 이 목록도 자동으로 따라간다.
final List<SeaLocation> sampleLocations = [
  for (final c in golfCourses) c.toLocation(),
];
