import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/local_storage_service.dart';
import '../../domain/models/avatar_customization.dart';
import '../../domain/models/character.dart';
import '../widgets/pixel_character.dart';

/// 見た目カスタマイズ画面（アバタースタジオ）
///
/// 形状・カラー・装飾・演出の4軸でプレイヤーの見た目を編集する。
/// 変更は即座に保存され、ホーム/バトル/リザルト/ランキングに反映される。
class AvatarStudioScreen extends StatefulWidget {
  /// カスタマイズ適用前のベースキャラクター
  final Character baseCharacter;

  const AvatarStudioScreen({super.key, required this.baseCharacter});

  @override
  State<AvatarStudioScreen> createState() => _AvatarStudioScreenState();
}

class _AvatarStudioScreenState extends State<AvatarStudioScreen> {
  final _storage = LocalStorageService();
  final _random = Random();
  late AvatarCustomization _customization;

  @override
  void initState() {
    super.initState();
    _customization =
        AvatarCustomization.fromStorageString(_storage.getAvatarCustomization());
  }

  Future<void> _update(AvatarCustomization next) async {
    setState(() => _customization = next);
    await _storage.saveAvatarCustomization(next.toStorageString());
  }

  Future<void> _shuffle() async {
    await _update(AvatarCustomization(
      headIndex: _random.nextInt(AvatarCustomization.headVariations),
      bodyIndex: _random.nextInt(AvatarCustomization.bodyVariations),
      armIndex: _random.nextInt(AvatarCustomization.armVariations),
      legIndex: _random.nextInt(AvatarCustomization.legVariations),
      colorPaletteIndex:
          _random.nextInt(AvatarCustomization.paletteVariations),
      accessoryIndex: _random.nextInt(AvatarCustomization.accessoryVariations),
      auraIndex: _random.nextInt(AvatarCustomization.auraVariations),
    ));
  }

  Future<void> _reset() async {
    await _update(const AvatarCustomization());
  }

  Character get _preview => _customization.applyTo(widget.baseCharacter);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        title: const Text('アバタースタジオ'),
        backgroundColor: const Color(0xFF1B2838),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'リセット（全ておまかせ）',
            onPressed: _customization.isEmpty ? null : _reset,
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildPreviewCard(),
          const SizedBox(height: 16),
          _buildAxisCard(
            title: '形状',
            icon: Icons.accessibility_new,
            color: const Color(0xFF4ECDC4),
            children: [
              _buildSlotRow(
                label: 'あたま',
                names: const ['丸', '角', 'とがり', '大きめ', 'ヘルメット', 'ツイン', 'フード', 'モヒカン'],
                selected: _customization.headIndex,
                previewBuilder: (i) => widget.baseCharacter.copyWith(headIndex: i),
                onSelect: (i) => _update(_customization.copyWith(headIndex: i)),
              ),
              _buildSlotRow(
                label: 'からだ',
                names: const ['標準', 'ワイド', 'がっちり', '逆三角', '丸型', 'スリム'],
                selected: _customization.bodyIndex,
                previewBuilder: (i) => widget.baseCharacter.copyWith(bodyIndex: i),
                onSelect: (i) => _update(_customization.copyWith(bodyIndex: i)),
              ),
              _buildSlotRow(
                label: 'うで',
                names: const ['ショート', 'ミドル', 'ロング', 'パワー', 'バンザイ'],
                selected: _customization.armIndex,
                previewBuilder: (i) => widget.baseCharacter.copyWith(armIndex: i),
                onSelect: (i) => _update(_customization.copyWith(armIndex: i)),
              ),
              _buildSlotRow(
                label: 'あし',
                names: const ['標準', 'しっかり', 'ロング', 'ワイド', 'ホイール'],
                selected: _customization.legIndex,
                previewBuilder: (i) => widget.baseCharacter.copyWith(legIndex: i),
                onSelect: (i) => _update(_customization.copyWith(legIndex: i)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildAxisCard(
            title: 'カラー',
            icon: Icons.palette,
            color: const Color(0xFFFFD93D),
            children: [
              _buildSlotRow(
                label: 'カラーリング',
                names: const [
                  'クリムゾン', 'ターコイズ', 'サン', 'バイオレット', 'エメラルド', 'サクラ',
                  'サンセット', 'スカイ', 'シルバー', 'ナイト', 'ライム', 'ゴールド',
                ],
                selected: _customization.colorPaletteIndex,
                previewBuilder: (i) =>
                    widget.baseCharacter.copyWith(colorPaletteIndex: i),
                onSelect: (i) =>
                    _update(_customization.copyWith(colorPaletteIndex: i)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildAxisCard(
            title: '装飾',
            icon: Icons.star,
            color: const Color(0xFFFD79A8),
            children: [
              _buildSlotRow(
                label: 'アクセサリー',
                names: const ['なし', 'アンテナ', 'とんがり帽', 'ツノ', '王冠', 'リボン', 'サングラス', 'マフラー'],
                selected: _customization.accessoryIndex,
                previewBuilder: (i) =>
                    widget.baseCharacter.copyWith(accessoryIndex: i),
                onSelect: (i) =>
                    _update(_customization.copyWith(accessoryIndex: i)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildAxisCard(
            title: '演出',
            icon: Icons.auto_awesome,
            color: const Color(0xFF6C5CE7),
            children: [
              _buildSlotRow(
                label: 'オーラ',
                names: const ['なし', '光輪', '星屑', '炎', '電撃', '雪'],
                selected: _customization.auraIndex,
                previewBuilder: (i) => widget.baseCharacter.copyWith(auraIndex: i),
                onSelect: (i) => _update(_customization.copyWith(auraIndex: i)),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPreviewCard() {
    final customized = _customization.customizedCount;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF6C5CE7).withValues(alpha: 0.25),
            const Color(0xFF1B2838),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF6C5CE7).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          PixelCharacter(character: _preview, size: 140),
          const SizedBox(height: 10),
          Text(
            widget.baseCharacter.name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            customized == 0
                ? 'すべておまかせ（元の見た目）'
                : '$customized/7 スロットをカスタマイズ中',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _shuffle,
              icon: const Icon(Icons.casino, size: 18),
              label: const Text('シャッフル'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFFD93D),
                side: const BorderSide(color: Color(0xFFFFD93D)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAxisCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2838),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ...children,
        ],
      ),
    );
  }

  /// 1スロット分の選択行（おまかせ + 各バリエーションの横スクロール）
  Widget _buildSlotRow({
    required String label,
    required List<String> names,
    required int selected,
    required Character Function(int index) previewBuilder,
    required ValueChanged<int> onSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: names.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              if (i == 0) {
                return _buildOptionTile(
                  name: 'おまかせ',
                  isSelected: selected == AvatarCustomization.unset,
                  character: null,
                  onTap: () => onSelect(AvatarCustomization.unset),
                );
              }
              final index = i - 1;
              return _buildOptionTile(
                name: names[index],
                isSelected: selected == index,
                character: previewBuilder(index),
                onTap: () => onSelect(index),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOptionTile({
    required String name,
    required bool isSelected,
    required Character? character,
    required VoidCallback onTap,
  }) {
    const selectedColor = Color(0xFF6C5CE7);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 76,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? selectedColor.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? selectedColor : Colors.white12,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            if (character != null)
              PixelCharacter(character: character, size: 56)
            else
              const SizedBox(
                width: 56,
                height: 56,
                child: Icon(Icons.shuffle, color: Colors.white38, size: 28),
              ),
            const SizedBox(height: 4),
            Text(
              name,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white60,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
