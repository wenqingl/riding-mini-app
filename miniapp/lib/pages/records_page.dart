import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:open_filex/open_filex.dart';
import '../models/record.dart';
import '../services/api_service.dart';
import 'login_page.dart' show kBaseUrl;

class RecordsPage extends StatefulWidget {
  final String token;
  final VoidCallback onLogout;

  const RecordsPage({super.key, required this.token, required this.onLogout});

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  late String _token;
  late final ApiService _api;

  List<RideRecord> _records = [];
  bool _loading = false;
  bool _merging = false;
  String? _mergeResultMsg;

  @override
  void initState() {
    super.initState();
    _token = widget.token;
    _api = ApiService(kBaseUrl);
    _loadRecords();
  }

  int get _selectedCount => _records.where((r) => r.selected).length;
  List<String> get _selectedIds =>
      _records.where((r) => r.selected).map((r) => r.id).toList();

  // ── Auth helpers ──────────────────────────────────────────────────────────

  Future<bool> _tryRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    final refresh = prefs.getString('refresh_token');
    if (refresh == null) return false;
    final newToken = await _api.refreshToken(refresh);
    if (newToken != null && newToken.isNotEmpty) {
      await prefs.setString('access_token', newToken);
      setState(() => _token = newToken);
      return true;
    }
    return false;
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    widget.onLogout();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadRecords({bool retried = false}) async {
    setState(() => _loading = true);
    try {
      final raw = await _api.getRecords(_token);
      setState(() {
        _records = raw.map(RideRecord.fromJson).toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!retried && e.statusCode == 401) {
        if (await _tryRefresh()) {
          return _loadRecords(retried: true);
        }
      }
      setState(() => _loading = false);
      _showSnack('加载失败: ${e.message}', isError: true);
    } catch (e) {
      setState(() => _loading = false);
      _showSnack('加载失败', isError: true);
    }
  }

  // ── Merge actions ─────────────────────────────────────────────────────────

  Future<void> _doMergeUpload({bool retried = false}) async {
    if (_selectedCount < 2) {
      _showSnack('请至少选择 2 条记录');
      return;
    }
    setState(() {
      _merging = true;
      _mergeResultMsg = null;
    });
    try {
      final res = await _api.mergeAndUpload(_selectedIds, _token);
      final success = res['success'] == true;
      setState(() {
        _mergeResultMsg = success ? '合并并上传成功 ✓' : '合并成功，上传失败';
        _merging = false;
      });
      _showSnack(_mergeResultMsg!, isError: !success);
    } on ApiException catch (e) {
      if (!retried && e.statusCode == 401) {
        if (await _tryRefresh()) {
          return _doMergeUpload(retried: true);
        }
      }
      setState(() => _merging = false);
      _showSnack('合并失败: ${e.message}', isError: true);
    } catch (_) {
      setState(() => _merging = false);
      _showSnack('合并失败', isError: true);
    }
  }

  Future<void> _doMergeDownload({bool retried = false}) async {
    if (_selectedCount < 2) {
      _showSnack('请至少选择 2 条记录');
      return;
    }
    setState(() => _merging = true);
    try {
      final bytes = await _api.mergeDownload(_selectedIds, _token);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/merged.gpx');
      await file.writeAsBytes(bytes);
      setState(() => _merging = false);
      await OpenFilex.open(file.path);
    } on ApiException catch (e) {
      if (!retried && e.statusCode == 401) {
        if (await _tryRefresh()) {
          return _doMergeDownload(retried: true);
        }
      }
      setState(() => _merging = false);
      _showSnack('下载失败: ${e.message}', isError: true);
    } catch (_) {
      setState(() => _merging = false);
      _showSnack('下载失败', isError: true);
    }
  }

  void _resetSelection() {
    setState(() {
      for (final r in _records) {
        r.selected = false;
      }
      _mergeResultMsg = null;
    });
  }

  // ── UI helpers ────────────────────────────────────────────────────────────

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red[700] : null,
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('骑行记录'),
        backgroundColor: const Color(0xFF4A90D9),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: _loading ? null : _loadRecords,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '退出',
            onPressed: _logout,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? _buildEmpty()
              : _buildList(),
      bottomNavigationBar: _selectedCount > 0 ? _buildActionBar() : null,
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.directions_bike_outlined,
              size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('暂无骑行记录', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadRecords, child: const Text('重新加载')),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _records.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final r = _records[i];
        return CheckboxListTile(
          value: r.selected,
          onChanged: (_) {
            setState(() => r.selected = !r.selected);
          },
          title: Text(r.title ?? '骑行 ${r.date}',
              style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text('${r.date}  |  ${r.distanceKm} km  |  ${r.duration}'),
          secondary: const Icon(Icons.directions_bike,
              color: Color(0xFF4A90D9)),
          activeColor: const Color(0xFF4A90D9),
        );
      },
    );
  }

  Widget _buildActionBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_mergeResultMsg != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_mergeResultMsg!,
                    style: const TextStyle(color: Colors.green)),
              ),
            Row(
              children: [
                Text('已选 $_selectedCount 条',
                    style: const TextStyle(color: Colors.grey)),
                const Spacer(),
                TextButton(
                  onPressed: _resetSelection,
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90D9),
                    foregroundColor: Colors.white,
                  ),
                  icon: _merging
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.upload, size: 18),
                  label: const Text('合并上传'),
                  onPressed: _merging ? null : _doMergeUpload,
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('下载GPX'),
                  onPressed: _merging ? null : _doMergeDownload,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
