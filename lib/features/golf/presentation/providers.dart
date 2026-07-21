import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../locations/presentation/providers.dart';
import '../data/golf_courses_data.dart';
import '../data/models/golf_course.dart';

/// 전국 골프장 목록.
final golfCoursesProvider = Provider<List<GolfCourse>>((ref) => golfCourses);

/// id로 골프장 조회(없으면 null).
GolfCourse? golfCourseById(String id) {
  for (final c in golfCourses) {
    if (c.id == id) return c;
  }
  return null;
}

/// 현재 선택된 골프장. 공용 [selectedLocationProvider]의 id로 조회한다.
/// (검색 지오코딩 등 목록에 없는 지점을 고르면 null이 될 수 있다.)
final selectedCourseProvider = Provider<GolfCourse?>((ref) {
  final loc = ref.watch(selectedLocationProvider);
  return golfCourseById(loc.id);
});
