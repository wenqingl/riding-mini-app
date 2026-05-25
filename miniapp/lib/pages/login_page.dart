import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// 配置后端地址 — 与 .env 中的 BASE_URL 保持一致
/// 生产环境可通过 --dart-define=BASE_URL=https://... 注入
const String kBaseUrl =
    String.fromEnvironment('BASE_URL', defaultValue: 'http://10.0.2.2:8000');

class LoginPage extends StatefulWidget {
  final void Function(String token) onLogin;

  const LoginPage({super.key, required this.onLogin});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final WebViewController _controller;
  bool _webViewVisible = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: _onNavigate,
        onPageFinished: _onPageFinished,
      ));
  }

  /// 后端 /auth/callback/web 返回包含 token 的 HTML 页面
  /// 同时在页面 URL 中包含 access_token query param 作为备选
  NavigationDecision _onNavigate(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.navigate;

    // 检查 URL query 中是否直接带了 token（deep-link 方式）
    final token = uri.queryParameters['access_token'];
    if (token != null && token.isNotEmpty) {
      _saveAndLogin(token, uri.queryParameters['refresh_token']);
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  Future<void> _onPageFinished(String url) async {
    // 从页面 JS 上下文提取 token（callback/web 页面注入了 JSON payload）
    try {
      final result = await _controller.runJavaScriptReturningResult(
        'JSON.stringify(window.__tokenPayload)',
      );
      if (result != 'null' && result != 'undefined') {
        final raw = result.toString().replaceAll(r'\"', '"');
        // runJavaScriptReturningResult 返回带引号的字符串，先解一层
        String jsonStr = raw;
        if (jsonStr.startsWith('"') && jsonStr.endsWith('"')) {
          jsonStr = jsonDecode(jsonStr) as String;
        }
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        final token = data['access_token'] as String?;
        final refresh = data['refresh_token'] as String?;
        if (token != null && token.isNotEmpty) {
          _saveAndLogin(token, refresh);
          return;
        }
      }
    } catch (_) {}

    // 备选：直接在页面 DOM 中查找 token 文本（callback/web 的 <pre id="token"> 元素）
    try {
      final result = await _controller.runJavaScriptReturningResult(
        'document.getElementById("token")?.innerText ?? ""',
      );
      final token = result.toString().trim().replaceAll('"', '');
      if (token.isNotEmpty) {
        _saveAndLogin(token, null);
      }
    } catch (_) {}
  }

  Future<void> _saveAndLogin(String token, String? refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
    if (refreshToken != null) {
      await prefs.setString('refresh_token', refreshToken);
    }
    if (mounted) {
      widget.onLogin(token);
    }
  }

  void _startOAuth() {
    setState(() => _webViewVisible = true);
    _controller.loadRequest(Uri.parse('$kBaseUrl/auth/login'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: _webViewVisible
          ? Column(
              children: [
                AppBar(
                  backgroundColor: const Color(0xFF1A1A2E),
                  foregroundColor: Colors.white,
                  title: const Text('行者授权'),
                  leading: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _webViewVisible = false),
                  ),
                ),
                Expanded(child: WebViewWidget(controller: _controller)),
              ],
            )
          : _buildLanding(context),
    );
  }

  Widget _buildLanding(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.directions_bike,
                  size: 80, color: Color(0xFF4A90D9)),
              const SizedBox(height: 24),
              const Text(
                '行者骑行合并',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '合并多段骑行数据，一键上传行者',
                style: TextStyle(color: Colors.white60, fontSize: 15),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90D9),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _startOAuth,
                  child: const Text('登录行者账号',
                      style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
