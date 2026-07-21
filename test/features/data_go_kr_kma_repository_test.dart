import 'dart:convert';

import 'package:golf_windy/features/kma_weather/data/repositories/data_go_kr_kma_repository.dart';
import 'package:golf_windy/features/locations/data/models/sea_location.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// data.go.kr 표준 봉투로 감싼 응답 본문을 만든다.
String _envelope(List<Map<String, String>> items) => jsonEncode({
  'response': {
    'header': {'resultCode': '00', 'resultMsg': 'NORMAL_SERVICE'},
    'body': {
      'items': {'item': items},
    },
  },
});

void main() {
  const loc = SeaLocation(
    id: 'x',
    name: 'x',
    region: 'x',
    latitude: 37.5,
    longitude: 127.0,
  );

  test('단기예보 + 초단기예보 + 초단기실황을 우선순위대로 병합한다', () async {
    // 같은 시각(20260721 1200)에 대해 세 서비스가 서로 다른 값을 준다.
    final client = MockClient((req) async {
      final path = req.url.path;
      if (path.endsWith('getVilageFcst')) {
        return http.Response(
          _envelope([
            _fcst('TMP', '20'),
            _fcst('POP', '30'),
            _fcst('SKY', '1'),
            _fcst('PTY', '0'),
            _fcst('REH', '50'),
            _fcst('WSD', '3'),
            _fcst('VEC', '90'),
          ]),
          200,
        );
      }
      if (path.endsWith('getUltraSrtFcst')) {
        return http.Response(
          _envelope([
            _fcst('T1H', '22'), // 초단기 기온 → TMP로 정규화
            _fcst('SKY', '3'),
            _fcst('WSD', '5'),
            _fcst('VEC', '180'),
          ]),
          200,
        );
      }
      // getUltraSrtNcst — obsrValue + baseDate/baseTime.
      return http.Response(
        _envelope([
          _ncst('T1H', '25'),
          _ncst('REH', '60'),
          _ncst('WSD', '7'),
          _ncst('VEC', '270'),
        ]),
        200,
      );
    });

    final repo = DataGoKrKmaRepository(client: client, serviceKey: 'test');
    final forecast = await repo.fetchForecast(loc);
    final h = forecast.hourly.firstWhere(
      (e) => e.time == DateTime(2026, 7, 21, 12),
    );

    // 실황이 최우선: 기온·습도·풍속·풍향은 실황 값.
    expect(h.tempC, 25);
    expect(h.humidityPercent, 60);
    expect(h.windSpeedMs, 7);
    expect(h.windDirDeg, 270);
    // 실황에 없는 SKY는 초단기예보 값(3), POP는 단기예보 값(30)이 유지된다.
    expect(h.skyCode, 3);
    expect(h.popPercent, 30);
  });

  test('초단기 호출이 실패해도 단기예보만으로 동작한다(best-effort)', () async {
    final client = MockClient((req) async {
      if (req.url.path.endsWith('getVilageFcst')) {
        return http.Response(
          _envelope([
            _fcst('TMP', '18'),
            _fcst('WSD', '4'),
            _fcst('VEC', '45'),
          ]),
          200,
        );
      }
      return http.Response('error', 500); // 초단기 두 호출 모두 실패.
    });

    final repo = DataGoKrKmaRepository(client: client, serviceKey: 'test');
    final forecast = await repo.fetchForecast(loc);
    final h = forecast.hourly.firstWhere(
      (e) => e.time == DateTime(2026, 7, 21, 12),
    );
    expect(h.tempC, 18);
    expect(h.windDirDeg, 45);
  });
}

Map<String, String> _fcst(String category, String value) => {
  'fcstDate': '20260721',
  'fcstTime': '1200',
  'category': category,
  'fcstValue': value,
};

Map<String, String> _ncst(String category, String value) => {
  'baseDate': '20260721',
  'baseTime': '1200',
  'category': category,
  'obsrValue': value,
};
