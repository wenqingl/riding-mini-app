import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// 对应小程序 utils/api.js 的 Dart 实现
/// 后端 API 端点保持一致：/api/records, /api/merge, /api/merge-and-upload, /auth/refresh
class ApiService {
  final String baseUrl;

  const ApiService(this.baseUrl);

  Map<String, String> _authHeaders(String token) => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  /// GET /api/records — 获取骑行记录列表
  Future<List<Map<String, dynamic>>> getRecords(String token) async {
    final uri = Uri.parse('$baseUrl/api/records');
    final res = await http.get(uri, headers: _authHeaders(token));
    _checkStatus(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final raw = (body['records'] as List<dynamic>? ?? []);
    return raw.cast<Map<String, dynamic>>();
  }

  /// POST /api/merge-and-upload — 合并并上传回行者
  Future<Map<String, dynamic>> mergeAndUpload(
      List<String> recordIds, String token) async {
    final uri = Uri.parse('$baseUrl/api/merge-and-upload');
    final res = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({'record_ids': recordIds, 'format': 'gpx'}),
    );
    _checkStatus(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// POST /api/merge — 合并并下载文件（返回二进制）
  Future<Uint8List> mergeDownload(List<String> recordIds, String token) async {
    final uri = Uri.parse('$baseUrl/api/merge');
    final res = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({'record_ids': recordIds, 'format': 'gpx'}),
    );
    _checkStatus(res);
    return res.bodyBytes;
  }

  /// POST /auth/refresh — 刷新 access_token
  Future<String?> refreshToken(String refreshToken) async {
    final uri = Uri.parse(
        '$baseUrl/auth/refresh?refresh_token=${Uri.encodeComponent(refreshToken)}');
    final res = await http.post(uri);
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['access_token'] as String?;
    }
    return null;
  }

  void _checkStatus(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      String detail = 'Request failed (${res.statusCode})';
      try {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        detail = body['detail'] as String? ?? detail;
      } catch (_) {}
      throw ApiException(detail, res.statusCode);
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  const ApiException(this.message, this.statusCode);

  @override
  String toString() => 'ApiException($statusCode): $message';
}
