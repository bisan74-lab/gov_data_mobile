// 공공데이터포털(기상청 단기예보) API 연결 진단 스크립트.
//
// 사용법:
//   dart run tool/check_api.dart <서비스키>
//
// 골프윈디가 쓰는 기상청_단기예보((구)동네예보) getVilageFcst를 호출해
// 상태코드와 응답 앞부분을 출력한다.
//
// 판정 기준:
//   resultCode 00 (NORMAL_SERVICE) → 키·규격 모두 정상, 응답 필드 확인 가능
//   resultCode 03 (NO_DATA)        → 키는 정상, 해당 조건에 데이터가 없음
//   Unauthorized / 30번대 코드     → 키 미동기화 또는 잘못된 키
//
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print('사용법: dart run tool/check_api.dart <서비스키>');
    exit(1);
  }
  final key = args.first;
  // 발표 시각이 지난 최근 base_time을 쓰기 위해 어제 05시 발표를 조회한다.
  final yesterday = DateTime.now().subtract(const Duration(days: 1));
  final ymd =
      '${yesterday.year}'
      '${yesterday.month.toString().padLeft(2, '0')}'
      '${yesterday.day.toString().padLeft(2, '0')}';

  final cases = <String, Uri>{
    // 서울(격자 nx=60, ny=127) 단기예보.
    '기상청 단기예보 서울 어제 05시 발표': Uri.https(
      'apis.data.go.kr',
      '/1360000/VilageFcstInfoService_2.0/getVilageFcst',
      {
        'serviceKey': key,
        'dataType': 'JSON',
        'base_date': ymd,
        'base_time': '0500',
        'nx': '60',
        'ny': '127',
        'pageNo': '1',
        'numOfRows': '20',
      },
    ),
  };

  final client = HttpClient();
  for (final entry in cases.entries) {
    try {
      final req = await client.getUrl(entry.value);
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      final head = body.replaceAll('\n', ' ');
      print('--- ${entry.key}');
      print('    HTTP ${res.statusCode}');
      print('    ${head.substring(0, head.length > 800 ? 800 : head.length)}');
      if (body.contains('NORMAL_SERVICE')) {
        print('    ✅ 정상 — 위 응답 전체를 개발 세션에 붙여넣으면 필드 매핑을 확정할 수 있습니다.');
      } else if (body.contains('NO_DATA')) {
        print('    ⚠️ 키는 정상, 이 조건에는 데이터가 없습니다.');
      } else if (body.contains('Unauthorized') || body.contains('SERVICE_KEY')) {
        print('    ❌ 키 미동기화 또는 잘못된 키입니다.');
      }
    } catch (e) {
      print('--- ${entry.key}');
      print('    오류: $e');
    }
    print('');
  }
  client.close();
}
