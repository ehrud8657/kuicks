import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api',
  );

  Future<List<Semester>> fetchSemesters() async {
    final response = await _client.get(Uri.parse('$baseUrl/semesters/'));
    if (response.statusCode != 200) {
      throw Exception('학기 정보를 불러오지 못했습니다.');
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    final items = body is List ? body : body['results'] as List<dynamic>;
    return items
        .map((item) => Semester.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
