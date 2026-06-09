import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/services/qr_battle_service.dart';
import '../../domain/services/service_locator.dart';
import 'qr_guest_preview_screen.dart';

/// URL入力画面（対戦コードをペーストして対戦相手を読み取る）
class UrlInputScreen extends StatefulWidget {
  const UrlInputScreen({super.key});

  @override
  State<UrlInputScreen> createState() => _UrlInputScreenState();
}

class _UrlInputScreenState extends State<UrlInputScreen> {
  final _controller = TextEditingController();
  String? _errorMessage;
  bool _isProcessing = false;
  bool _hasInput = false;

  bool get _canSubmit => _hasInput && !_isProcessing;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    final hasInput = _controller.text.trim().isNotEmpty;
    if (hasInput == _hasInput && _errorMessage == null) return;

    setState(() {
      _hasInput = hasInput;
      _errorMessage = null;
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      setState(() => _errorMessage = 'クリップボードに対戦URLがありません');
      return;
    }
    _controller.text = text;
  }

  void _handleSubmit() {
    if (_isProcessing) return;
    final input = _controller.text.trim();
    if (input.isEmpty) {
      setState(() => _errorMessage = '対戦コードまたはURLを入力してください');
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final encoded = QrBattleService.normalizeBattleInput(input);
      final guest = ServiceLocator().qrBattleService.decodeAsGuest(encoded);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => QrGuestPreviewScreen(
              guest: guest,
              fromFriendMenu: true,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = '無効な対戦コードです。正しいURLまたはコードを入力してください。';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        title: const Text('対戦コードを入力'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeaderCard(),
              const SizedBox(height: 18),
              TextField(
                controller: _controller,
                minLines: 4,
                maxLines: 5,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: '対戦URL / コード',
                  labelStyle: const TextStyle(color: Colors.white70),
                  hintText: 'https://.../?battle=',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: const Color(0xFF1B2838),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.greenAccent),
                  ),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _errorMessage != null
                    ? _buildMessageRow(
                        key: const ValueKey('error'),
                        icon: Icons.error_outline,
                        text: _errorMessage!,
                        color: Colors.redAccent,
                      )
                    : _hasInput
                        ? _buildMessageRow(
                            key: const ValueKey('ready'),
                            icon: Icons.check_circle_outline,
                            text: '読み取り準備完了',
                            color: Colors.greenAccent,
                          )
                        : const SizedBox(key: ValueKey('empty'), height: 20),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isProcessing ? null : _pasteFromClipboard,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        side: BorderSide(
                          color: Colors.greenAccent.withValues(alpha: 0.5),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.paste, color: Colors.greenAccent),
                      label: const Text(
                        '貼り付け',
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _canSubmit ? _handleSubmit : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Colors.greenAccent.withValues(alpha: 0.2),
                        disabledBackgroundColor: Colors.white10,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color:
                              _canSubmit ? Colors.greenAccent : Colors.white24,
                        ),
                      ),
                      icon: _isProcessing
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.greenAccent,
                              ),
                            )
                          : Icon(
                              Icons.arrow_forward,
                              color: _canSubmit
                                  ? Colors.greenAccent
                                  : Colors.white38,
                            ),
                      label: Text(
                        _isProcessing ? '解析中' : '読み取る',
                        style: TextStyle(
                          color:
                              _canSubmit ? Colors.greenAccent : Colors.white38,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF12263A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.greenAccent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.sports_mma, color: Colors.greenAccent),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'フレンド対戦を読み取る',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '共有URLを入れると、相手キャラと勝ち筋を確認できます。',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageRow({
    required Key key,
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Row(
      key: key,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: color, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
