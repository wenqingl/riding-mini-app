import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/login_page.dart';
import 'pages/records_page.dart';

void main() {
  runApp(const XingzheApp());
}

class XingzheApp extends StatelessWidget {
  const XingzheApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '行者骑行合并',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4A90D9)),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _token;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkToken();
  }

  Future<void> _checkToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    setState(() {
      _token = token;
      _loading = false;
    });
  }

  void _onLogin(String token) {
    setState(() => _token = token);
  }

  void _onLogout() {
    setState(() => _token = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_token == null || _token!.isEmpty) {
      return LoginPage(onLogin: _onLogin);
    }
    return RecordsPage(token: _token!, onLogout: _onLogout);
  }
}
