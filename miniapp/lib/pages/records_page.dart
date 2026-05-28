import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/upload_record.dart';
import '../services/xingzhe_api.dart';
import '../services/fit_merge_service.dart';

class RecordsPage extends StatefulWidget {
  final String token;
  final VoidCallback onLogout;
  const RecordsPage({super.key, required this.token, required this.onLogout});

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  late String _token;
  late final XingzheApiService _api;

  List<UploadRecord> _records = [];
  bool _loading = false;
  bool _merging = false;
  String _mergeStatus = '';

  @override
  void initState() {
    super.initState();
    _token = widget.token;
    _api = XingzheApiService();
    _loadRecords();
  }

  int get _selectedCount => _records.where((r) => r.selected).length;
  List<UploadRecord> get _selectedRecords =>
      _records.where((r) => r.selected).toList();

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<bool> _tryRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    final refresh = prefs.getString('refresh_token');
    if (refresh == null) return false;
    final newToken = await _api.refreshToken(refresh);
    if (newToken != null) {
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

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> _loadRecords({bool retried = false}) async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.getUploads(_token).catchError((_) => <Map<String, dynamic>>[]),
        _api.getActivities(_token).catchError((_) => <Map<String, dynamic>>[]),
      ]);

      final uploadsRaw = results[0];
      final activitiesRaw = results[1];

      // uploads 优先（有 fit_file）；activities 补充不重复的
      final uploadIds = uploadsRaw.map((r) => r['id']?.toString()).toSet();
      final extra = activitiesRaw
          .where((r) => !uploadIds.contains(r['id']?.toString()))
          .toList();

      setState(() {
        _records = [...uploadsRaw, ...extra]
            .map(UploadRecord.fromJson)
            .toList();
        _loading = false;
      });
    } on XingzheApiException catch (e) {
      if (!retried && e.statusCode == 401 && await _tryRefresh()) {
        return _loadRecords(retried: true);
      }
      setState(() => _loading = false);
      _showSnack('加载失败: ${e.message}', isError: true);
    } catch (e) {
      setState(() => _loading = false);
      _showSnack('加载失败: $e', isError: true);
    }
  }

  // ── Merge & Upload ────────────────────────────────────────────────────────

  Future<void> _doMergeAndUpload({bool retried = false}) async {
    final selected = _selectedRecords;
    if (selected.length < 2) {
      _showSnack('请至少选择 2 条记录');
      return;
    }

    setState(() {
      _merging = true;
      _mergeStatus = '准备下载...';
    });

    try {
      // Step 1: 下载各条记录的 FIT 数据
      final fitFiles = <dynamic>[];
      for (int i = 0; i < selected.length; i++) {
        final r = selected[i];
        setState(() =>
            _mergeStatus = '下载第 ${i + 1}/${selected.length} 条数据...');

        if (r.hasFitFile) {
          // 直接下载 FIT 文件
          final bytes = await _api.downloadFit(_token, r.fitFileUrl!);
          fitFiles.add(bytes);
        } else {
          // 通过 stream 接口获取 GPS 数据，转换为 FIT
          final streamData =
              await _api.getActivityStream(_token, r.id);
          final fitBytes =
              await FitMergeService.streamJsonToFit(streamData);
          fitFiles.add(fitBytes);
        }
      }

      // Step 2: 本地合并
      setState(() => _mergeStatus = '合并 ${selected.length} 段数据...');
      final mergedFit =
          await FitMergeService.mergeFitFiles(fitFiles.cast());

      // Step 3: 上传
      setState(() => _mergeStatus = '上传到行者...');
      final titles = selected.map((r) => r.title).join('+');
      final uploadTitle =
          titles.length > 30 ? '${titles.substring(0, 28)}…' : titles;
      await _api.uploadFit(_token, mergedFit, title: uploadTitle);

      setState(() {
        _merging = false;
        _mergeStatus = '合并上传成功 ✓';
      });
      _showSnack('合并上传成功！');
      _resetSelection();
      _loadRecords();
    } on XingzheApiException catch (e) {
      if (!retried && e.statusCode == 401 && await _tryRefresh()) {
        return _doMergeAndUpload(retried: true);
      }
      setState(() {
        _merging = false;
        _mergeStatus = '';
      });
      _showSnack('失败: ${e.message}', isError: true);
    } catch (e) {
      setState(() {
        _merging = false;
        _mergeStatus = '';
      });
      _showSnack('失败: $e', isError: true);
    }
  }

  void _resetSelection() {
    setState(() {
      for (final r in _records) r.selected = false;
      _mergeStatus = '';
    });
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          isError ? Colors.red[700] : const Color(0xFF2E7D32),
    ));
  }

  // ── UI ────────────────────────────────────────────────────────────────────

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
            onPressed: _loading ? null : _loadRecords,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? _buildEmpty()
              : _buildList(),
      bottomNavigationBar:
          _selectedCount > 0 ? _buildActionBar() : null,
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
          const Text('暂无骑行记录',
              style: TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 16),
          ElevatedButton(
              onPressed: _loadRecords, child: const Text('重新加载')),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _records.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (context, i) => _buildItem(_records[i]),
    );
  }

  Widget _buildItem(UploadRecord r) {
    return InkWell(
      onTap: () => setState(() => r.selected = !r.selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: r.selected
            ? const Color(0xFF4A90D9).withOpacity(0.08)
            : Colors.transparent,
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // 左侧：缩略图 or 占位图
            _buildThumbnail(r),
            const SizedBox(width: 12),
            // 中间：文字信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // 来源标签
                      _buildSourceChip(r.hasFitFile),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${r.date}  ·  ${r.distanceKm} km  ·  ${r.duration}',
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 右侧：复选框
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: r.selected
                  ? const Icon(Icons.check_circle,
                      color: Color(0xFF4A90D9), size: 24,
                      key: ValueKey(true))
                  : Icon(Icons.radio_button_unchecked,
                      color: Colors.grey[400], size: 24,
                      key: const ValueKey(false)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(UploadRecord r) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 64,
        height: 64,
        child: r.thumbnailUrl != null
            ? Image.network(
                r.thumbnailUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _thumbPlaceholder(),
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : _thumbPlaceholder(),
              )
            : _thumbPlaceholder(),
      ),
    );
  }

  Widget _thumbPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: const Icon(Icons.directions_bike,
          color: Color(0xFF4A90D9), size: 32),
    );
  }

  Widget _buildSourceChip(bool hasFitFile) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: hasFitFile
            ? const Color(0xFF4A90D9).withOpacity(0.12)
            : Colors.orange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        hasFitFile ? '直连' : '流式',
        style: TextStyle(
          fontSize: 11,
          color: hasFitFile
              ? const Color(0xFF1565C0)
              : Colors.orange[800],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildActionBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, -2))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_merging || _mergeStatus.isNotEmpty) ...[
              Row(
                children: [
                  if (_merging)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF4A90D9)),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _mergeStatus,
                      style: TextStyle(
                        fontSize: 13,
                        color: _mergeStatus.contains('✓')
                            ? Colors.green[700]
                            : Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Text('已选 $_selectedCount 条',
                    style: TextStyle(
                        color: Colors.grey[600], fontSize: 14)),
                const Spacer(),
                TextButton(
                  onPressed: _resetSelection,
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90D9),
                  ),
                  icon: _merging
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.merge_type, size: 18),
                  label: const Text('合并上传'),
                  onPressed: _merging ? null : _doMergeAndUpload,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
