import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8000');

/// A request failed. [fieldErrors] maps a field name ("amount", "end", ...)
/// to the server's message for it (from a 422 response).
class ApiException implements Exception {
  ApiException(this.message, {this.fieldErrors = const {}});

  final String message;
  final Map<String, String> fieldErrors;

  @override
  String toString() => message;
}

class CreateTripResult {
  const CreateTripResult(this.trip, {required this.created});

  final Trip trip;

  /// true: 201, a new trip. false: 200, the same trip was already stored.
  final bool created;
}

class ApiClient {
  ApiClient({http.Client? client, this.baseUrl = apiBaseUrl}) : _http = client ?? http.Client();

  final http.Client _http;
  final String baseUrl;

  static const _timeout = Duration(seconds: 10);

  Future<List<String>> getDays() async {
    final json = await _get('/api/days') as List<dynamic>;
    return json.cast<String>();
  }

  Future<List<Trip>> getTrips(String day) async {
    final json = await _get('/api/trips', {'date': day}) as List<dynamic>;
    return json.map((e) => Trip.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<DaySummary> getSummary(String day) async {
    final json = await _get('/api/summary', {'date': day});
    return DaySummary.fromJson(json as Map<String, dynamic>);
  }

  Future<CreateTripResult> createTrip(NewTrip trip) async {
    final response = await _send(() => _http.post(
          Uri.parse('$baseUrl/api/trips'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(trip.toJson()),
        ));
    if (response.statusCode == 201 || response.statusCode == 200) {
      return CreateTripResult(
        Trip.fromJson(_decode(response) as Map<String, dynamic>),
        created: response.statusCode == 201,
      );
    }
    throw _errorFrom(response);
  }

  Future<Object?> _get(String path, [Map<String, String>? query]) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final response = await _send(() => _http.get(uri));
    if (response.statusCode != 200) throw _errorFrom(response);
    return _decode(response);
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(_timeout);
    } on TimeoutException {
      throw ApiException('Сервер не отвечает. Проверьте, что он запущен.');
    } on http.ClientException {
      throw ApiException('Нет связи с сервером ($baseUrl).');
    }
  }

  Object? _decode(http.Response response) => jsonDecode(utf8.decode(response.bodyBytes));

  ApiException _errorFrom(http.Response response) {
    Object? detail;
    try {
      detail = (_decode(response) as Map<String, dynamic>)['detail'];
    } catch (_) {
      detail = null;
    }
    return errorFromDetail(response.statusCode, detail);
  }
}

/// Turns FastAPI's `detail` into a readable error.
/// 422: `detail` is a list of {loc, msg}; 409 and others: a string.
ApiException errorFromDetail(int statusCode, Object? detail) {
  if (detail is List) {
    final fieldErrors = <String, String>{};
    final lines = <String>[];
    for (final item in detail.whereType<Map<String, dynamic>>()) {
      final loc = item['loc'];
      final field = loc is List && loc.isNotEmpty ? loc.last.toString() : '';
      final msg = item['msg']?.toString() ?? 'invalid value';
      fieldErrors.putIfAbsent(field, () => msg);
      lines.add(field.isEmpty ? msg : '$field: $msg');
    }
    if (lines.isNotEmpty) return ApiException(lines.join('\n'), fieldErrors: fieldErrors);
  }
  if (detail is String && detail.isNotEmpty) return ApiException(detail);
  return ApiException('Ошибка сервера ($statusCode).');
}
