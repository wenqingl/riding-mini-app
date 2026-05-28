import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/xingzhe_api.dart';

class LoginPage extends StatefulWidget {
  final void Function(String token) onLogin;
  const LoginPage({super.key, required this.onLogin});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final WebViewController _controller;
  late final String _state;
  bool _webViewVisible = false;
  bool _exchanging = false;
  final _api = XingzheApiService();

  @override
  void initState() {
    super.initState();
    _state = base64Url.encode(
      List<int>.generate(12, (_) => Random.secure().nextInt(256)),
    );
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: _onNavigate,
      ));
  }

  NavigationDecision _onNavigate(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.navigate;

    final code = uri.queryParameters['code'];
    final returnedState = uri.queryParameters['state'];

    if (code != null && code.isNotEmpty) {
      if (returnedState != _state) {
        _showError('授权失败：state 不匹配');
        return NavigationDecision.prevent;
      }
      _exchangeCode(code);
      return NavigationDecision.prevent;
    }

    final token = uri.queryParameters['access_token'];
    if (token != null && token.isNotEmpty) {
      _saveAndLogin(token, uri.queryParameters['refresh_token']);
      return NavigationDecision.prevent;
    }

    return NavigationDecision.navigate;
  }

  Future<void> _exchangeCode(String code) async {
    if (_exchanging) return;
    setState(() => _exchanging = true);
    try {
      final tokenData = await _api.exchangeCode(code);
      final accessToken = tokenData['access_token'] as String?;
      final refreshToken = tokenData['refresh_token'] as String?;
      if (accessToken != null && accessToken.isNotEmpty) {
        await _saveAndLogin(accessToken, refreshToken);
      } else {
        _showError('授权失败：未获取到 token');
      }
    } catch (e) {
      _showError('授权失败：$e');
    } finally {
      if (mounted) setState(() => _exchanging = false);
    }
  }

  Future<void> _saveAndLogin(String token, String? refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
    if (refreshToken != null) {
      await prefs.setString('refresh_token', refreshToken);
    }
    if (mounted) widget.onLogin(token);
  }

  void _showError(String msg) {
    if (!mounted) return;
    setState(() => _webViewVisible = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red[700]),
    );
  }

  void _startOAuth() {
    setState(() => _webViewVisible = true);
    _controller.loadRequest(Uri.parse(buildAuthUrl(_state)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: _webViewVisible ? _buildWebView() : _buildLanding(),
    );
  }

  Widget _buildWebView() {
    return Column(
      children: [
        AppBar(
          backgroundColor: const Color(0xFF1A1A2E),
          foregroundColor: Colors.white,
          title: const Text('行者授权登录'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => _webViewVisible = false),
          ),
        ),
        if (_exchanging)
          const LinearProgressIndicator(color: Color(0xFF4A90D9)),
        Expanded(child: WebViewWidget(controller: _controller)),
      ],
    );
  }

  Widget _buildLanding() {
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
              const Text('行者骑行合并',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('选择多段骑行，合并成一条记录',
                  style: TextStyle(color: Colors.white60, fontSize: 15)),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90D9),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
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
