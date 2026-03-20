import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _controller.text = data!.text!;
    }
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
      // URLの場合は対戦パラメータを抽出、そうでなければ直接デコード
      String encoded = input;
      final uri = Uri.tryParse(input);
      if (uri != null && uri.hasScheme) {
        final param = uri.queryParameters['battle'];
        if (param != null) {
          encoded = param;
        }
      }

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
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.link, size: 64, color: Colors.greenAccent),
              const SizedBox(height: 16),
              const Text(
                '友達から受け取ったURLまたは\n対戦コードを貼り付けてください',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: 32),

              // テキスト入力フィールド
              TextField(
                controller: _controller,
                maxLines: 3,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'URLまたは対戦コードを貼り付け...',
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
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.paste, color: Colors.greenAccent),
                    onPressed: _pasteFromClipboard,
                    tooltip: 'クリップボードから貼り付け',
                  ),
                ),
              ),
              const SizedBox(height: 8),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  ),
                ),

              const SizedBox(height: 16),

              // 対戦開始ボタン
              ElevatedButton(
                onPressed: _isProcessing ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent.withValues(alpha: 0.2),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(color: Colors.greenAccent),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.greenAccent,
                        ),
                      )
                    : const Text(
                        '読み取る',
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
