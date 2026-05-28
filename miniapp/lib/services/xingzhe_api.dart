import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

// ── 行者 OAuth 配置 ────────────────────────────────────────────────────────
const kClientId = '2aa3a245c67a0e13860f';
const kClientSecret = '788126d076076f5f4a0a58e7c14de235a9ef5f7b';
const kApiBase = 'https://www.imxingzhe.com/openapi/v1';
const kAuthUrl = 'https://www.imxingzhe.com/oauth2/v2/authorize';
const kTokenUrl = 'https://www.imxingzhe.com/oauth2/v2/access_token/';

/// OAuth 回调 URI：使用行者注册时填写的 redirect_uri
/// 若使用 WebView 内拦截，需与行者开放平台配置一致
const kRedirectUri = 'http://localhost:8000/auth/callback/web';

// ── 构建授权 URL ───────────────────────────────────────────────────────────

String buildAuthUrl(String state) {
  final params = {
    'client_id': kClientId,
    'response_type': 'code',
    'state': state,
    'scope': 'write',
    'redirect_uri': kRedirectUri,
  };
  final query = params.entries
      .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
      .join('&');
  return '$kAuthUrl?$query';
}

// ── 行者 API 服务 ──────────────────────────────────────────────────────────

class XingzheApiService {
  final http.Client _client;

  XingzheApiService({http.Client? client}) : _client = client ?? http.Client();

  // ── Auth ──────────────────────────────────────────────────────────────────

  /// 用 authorization_code 换取 access_token
  /// 行者 token 接口要求 Authorization: Bearer client_id:client_secret
  Future<Map<String, dynamic>> exchangeCode(String code) async {
    final res = await _client.post(
      Uri.parse(kTokenUrl),
      headers: {
        'Authorization': 'Bearer $kClientId:$kClientSecret',
      },
      body: {
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': kRedirectUri,
      },
    ).timeout(const Duration(seconds: 30));
    _check(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// 刷新 access_token
  Future<String?> refreshToken(String refreshToken) async {
    final res = await _client.post(
      Uri.parse(kTokenUrl),
      headers: {
        'Authorization': 'Bearer $kClientId:$kClientSecret',
      },
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
      },
    ).timeout(const Duration(seconds: 30));
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['access_token'] as String?;
    }
    return null;
  }

  // ── Uploads list (骑行记录来源) ───────────────────────────────────────────

  /// GET /uploads/ — 获取已上传的骑行记录列表
  /// 每条记录包含 fit_file URI（可直接下载原始 FIT）
  Future<List<Map<String, dynamic>>> getUploads(
    String token, {
    int limit = 100,
    int offset = 0,
  }) async {
    final uri = Uri.parse('$kApiBase/uploads/').replace(
      queryParameters: {'limit': '$limit', 'offset': '$offset'},
    );
    final res = await _client.get(uri, headers: _bearer(token))
        .timeout(const Duration(seconds: 30));
    _check(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['results'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
  }

  // ── Activities list ────────────────────────────────────────────────────────

  /// GET /activities/ — 活动列表（含基础统计数据）
  Future<List<Map<String, dynamic>>> getActivities(
    String token, {
    int limit = 100,
    int offset = 0,
  }) async {
    final uri = Uri.parse('$kApiBase/activities/').replace(
      queryParameters: {'limit': '$limit', 'offset': '$offset'},
    );
    final res = await _client.get(uri, headers: _bearer(token))
        .timeout(const Duration(seconds: 30));
    _check(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['results'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
  }

  // ── FIT 文件下载 ───────────────────────────────────────────────────────────

  /// 下载 fit_file URL 指向的原始 FIT 二进制文件
  /// [fitFileUrl] 来自 /uploads/ 返回的 fit_file 字段
  Future<Uint8List> downloadFit(String token, String fitFileUrl) async {
    final res = await _client.get(
      Uri.parse(fitFileUrl),
      headers: _bearer(token),
    ).timeout(const Duration(seconds: 60));
    _check(res);
    return res.bodyBytes;
  }

  // ── 上传合并后的 FIT ──────────────────────────────────────────────────────

  /// POST /uploads/ — 上传合并后的 FIT 文件
  Future<Map<String, dynamic>> uploadFit(
    String token,
    Uint8List fitBytes, {
    String title = '合并骑行记录',
    int sport = 0,
  }) async {
    final md5Hash = md5.convert(fitBytes).toString();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$kApiBase/uploads/'),
    )
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['title'] = title
      ..fields['md5'] = md5Hash
      ..fields['sport'] = '$sport'
      ..fields['fit_filename'] = 'merged.fit'
      ..files.add(http.MultipartFile.fromBytes(
        'fit_file',
        fitBytes,
        filename: 'merged.fit',
      ));

    final streamed = await request.send().timeout(const Duration(seconds: 60));
    final res = await http.Response.fromStream(streamed);
    _check(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Activity stream ───────────────────────────────────────────────────────

  /// POST /activities/{id}/stream/ — 获取活动 GPS 流数据（JSON 格式）
  Future<dynamic> getActivityStream(String token, String activityId) async {
    final res = await _client.post(
      Uri.parse('$kApiBase/activities/$activityId/stream/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: '{}',
    ).timeout(const Duration(seconds: 60));
    _check(res);
    return jsonDecode(res.body);
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  Map<String, String> _bearer(String token) => {
        'Authorization': 'Bearer $token',
      };

  void _check(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      String detail = 'HTTP ${res.statusCode}';
      try {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        detail = body['detail'] as String? ?? detail;
      } catch (_) {}
      throw XingzheApiException(detail, res.statusCode);
    }
  }
}

class XingzheApiException implements Exception {
  final String message;
  final int statusCode;
  const XingzheApiException(this.message, this.statusCode);

  @override
  String toString() => 'XingzheApiException($statusCode): $message';
}
