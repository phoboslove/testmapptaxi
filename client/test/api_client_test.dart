import 'dart:convert';

import 'package:driver_diary/api/api_client.dart';
import 'package:driver_diary/api/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _tripJson = {
  'id': 'abc',
  'start': '2026-10-01T08:10:00+05:00',
  'end': '2026-10-01T08:32:00+05:00',
  'amount': 2400,
  'payment': 'card',
  'commission': 360,
  'day': '2026-10-01',
};

final _newTrip = NewTrip(
  id: 'abc',
  start: DateTime.utc(2026, 10, 1, 8, 10),
  end: DateTime.utc(2026, 10, 1, 8, 32),
  amount: 2400,
  payment: 'card',
  commission: 360,
);

ApiClient _clientReturning(int status, Object body) => ApiClient(
      baseUrl: 'http://test',
      client: MockClient((request) async => http.Response(jsonEncode(body), status)),
    );

void main() {
  test('201 means a new trip', () async {
    final result = await _clientReturning(201, _tripJson).createTrip(_newTrip);

    expect(result.created, isTrue);
    expect(result.trip.amount, 2400);
  });

  test('200 means the trip was already stored', () async {
    final result = await _clientReturning(200, _tripJson).createTrip(_newTrip);

    expect(result.created, isFalse);
  });

  test('409 shows the server message', () async {
    final api = _clientReturning(409, {'detail': "Trip with id 'abc' already exists with different data"});

    await expectLater(
      api.createTrip(_newTrip),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('already exists'))),
    );
  });

  test('422 maps detail[].msg to fields', () async {
    final api = _clientReturning(422, {
      'detail': [
        {'type': 'end_not_after_start', 'loc': ['body', 'end'], 'msg': 'end must be later than start'},
        {'type': 'greater_than', 'loc': ['body', 'amount'], 'msg': 'Input should be greater than 0'},
      ],
    });

    await expectLater(
      api.createTrip(_newTrip),
      throwsA(isA<ApiException>()
          .having((e) => e.fieldErrors['end'], 'end', 'end must be later than start')
          .having((e) => e.fieldErrors['amount'], 'amount', 'Input should be greater than 0')
          .having((e) => e.message, 'message', contains('end: end must be later than start'))),
    );
  });

  test('network failure becomes a readable error', () async {
    final api = ApiClient(
      baseUrl: 'http://test',
      client: MockClient((request) async => throw http.ClientException('connection refused')),
    );

    await expectLater(
      api.getDays(),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('Нет связи'))),
    );
  });

  test('POST body carries times with +05:00', () async {
    late Map<String, dynamic> sent;
    final api = ApiClient(
      baseUrl: 'http://test',
      client: MockClient((request) async {
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(_tripJson), 201);
      }),
    );

    await api.createTrip(_newTrip);

    expect(sent['start'], '2026-10-01T08:10:00+05:00');
    expect(sent['id'], 'abc');
  });
}
