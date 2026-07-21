import '../../../locations/data/models/sea_location.dart';

/// 골프장 한 곳.
///
/// 기상청·Open-Meteo 예보는 위경도만 있으면 조회되므로, 지도·날씨·바람 등
/// 기존 [SeaLocation] 기반 코드를 그대로 재사용하기 위해 [toLocation]으로
/// 변환한다. 홈 화면의 부가 정보(홀 수·유형·주소)는 이 모델에서만 쓴다.
class GolfCourse {
  const GolfCourse({
    required this.id,
    required this.name,
    required this.region,
    required this.latitude,
    required this.longitude,
    this.address = '',
    this.holes = 18,
    this.type = '',
    this.rank = 2,
  });

  final String id;
  final String name;

  /// 수도권 / 강원 / 충청 / 영남 / 호남 / 제주
  final String region;
  final double latitude;
  final double longitude;

  /// 도로명/지번 주소(있으면).
  final String address;

  /// 홀 수(9·18·27·36 등).
  final int holes;

  /// 회원제 / 대중제(퍼블릭) / 군 등.
  final String type;

  /// 지도 라벨 노출 우선순위(1=대형/유명 → 3=소규모). 작을수록 먼저 표시.
  final int rank;

  /// 예보·지도·검색이 공유하는 범용 지점 타입으로 변환.
  SeaLocation toLocation() => SeaLocation(
    id: id,
    name: name,
    region: region,
    latitude: latitude,
    longitude: longitude,
    rank: rank,
  );

  @override
  bool operator ==(Object other) => other is GolfCourse && other.id == id;

  @override
  int get hashCode => id.hashCode;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'region': region,
    'latitude': latitude,
    'longitude': longitude,
    'address': address,
    'holes': holes,
    'type': type,
    'rank': rank,
  };

  factory GolfCourse.fromJson(Map<String, dynamic> j) => GolfCourse(
    id: j['id'] as String,
    name: j['name'] as String,
    region: j['region'] as String,
    latitude: (j['latitude'] as num).toDouble(),
    longitude: (j['longitude'] as num).toDouble(),
    address: j['address'] as String? ?? '',
    holes: (j['holes'] as num?)?.toInt() ?? 18,
    type: j['type'] as String? ?? '',
    rank: (j['rank'] as num?)?.toInt() ?? 2,
  );
}
