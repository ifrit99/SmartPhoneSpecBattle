import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/sound_service.dart';
import '../../domain/services/service_locator.dart';

class DataBackupScreen extends StatefulWidget {
  const DataBackupScreen({super.key});

  @override
  State<DataBackupScreen> createState() => _DataBackupScreenState();
}

class _DataBackupScreenState extends State<DataBackupScreen> {
  final _sl = ServiceLocator();
  final _exportController = TextEditingController();
  final _importController = TextEditingController();
  bool _busy = false;
  bool _hasImportInput = false;

  @override
  void initState() {
    super.initState();
    _importController.addListener(_onImportTextChanged);
    _loadBackupCode();
  }

  @override
  void dispose() {
    _importController.removeListener(_onImportTextChanged);
    _exportController.dispose();
    _importController.dispose();
    super.dispose();
  }

  void _onImportTextChanged() {
    final hasInput = _importController.text.trim().isNotEmpty;
    if (hasInput == _hasImportInput) return;
    setState(() => _hasImportInput = hasInput);
  }

  Future<void> _loadBackupCode() async {
    final code = await _sl.storage.exportBackupCode();
    if (!mounted) return;
    setState(() => _exportController.text = code);
  }

  Future<void> _copyBackupCode() async {
    SoundService().playButton();
    await Clipboard.setData(ClipboardData(text: _exportController.text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('バックアップコードをコピーしました')),
    );
  }

  Future<void> _pasteImportCode() async {
    SoundService().playButton();
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('クリップボードが空です')),
      );
      return;
    }
    setState(() => _importController.text = text);
  }

  Future<void> _importBackupCode() async {
    final code = _importController.text.trim();
    if (code.isEmpty || _busy) return;

    SoundService().playButton();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B2838),
        title: const Text('データを復元しますか？', style: TextStyle(color: Colors.white)),
        content: const Text(
          '現在の進行状況はバックアップ内容で上書きされます。',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('復元する'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await _sl.storage.importBackupCode(code);
      await SoundService().init(_sl.storage);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('バックアップから復元しました')),
      );
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('バックアップコードを読み取れませんでした')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('データ保護'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _section(
              icon: Icons.ios_share,
              title: 'バックアップ',
              accent: Colors.cyanAccent,
              children: [
                const Text(
                  '進行状況・通貨・ガチャロスターをコード化します。',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 12),
                _codeField(_exportController, readOnly: true),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed:
                        _exportController.text.isEmpty ? null : _copyBackupCode,
                    icon: const Icon(Icons.copy),
                    label: const Text('コピー'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _section(
              icon: Icons.restore,
              title: '復元',
              accent: const Color(0xFFFFD700),
              children: [
                const Text(
                  '別端末や再インストール後に、保存したコードを貼り付けて復元できます。',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 12),
                _codeField(_importController),
                const SizedBox(height: 10),
                _restoreStatus(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _pasteImportCode,
                        icon: const Icon(Icons.content_paste),
                        label: const Text('貼り付け'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _busy || !_hasImportInput
                            ? null
                            : _importBackupCode,
                        icon: const Icon(Icons.restore),
                        label: const Text('復元'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD700),
                          foregroundColor: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _section({
    required IconData icon,
    required String title,
    required Color accent,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2838),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _codeField(TextEditingController controller, {bool readOnly = false}) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      minLines: 5,
      maxLines: 8,
      style: const TextStyle(
        color: Colors.white,
        fontFamily: 'monospace',
        fontSize: 12,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.22),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
      ),
    );
  }

  Widget _restoreStatus() {
    final color = _hasImportInput ? const Color(0xFF55EFC4) : Colors.white38;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: Row(
        key: ValueKey(_hasImportInput),
        children: [
          Icon(
            _hasImportInput ? Icons.check_circle_outline : Icons.info_outline,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _hasImportInput ? '復元コードを読み取り準備完了' : '復元コードを貼り付けると実行できます',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight:
                    _hasImportInput ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
