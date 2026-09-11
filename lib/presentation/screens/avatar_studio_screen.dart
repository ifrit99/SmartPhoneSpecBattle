import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/local_storage_service.dart';
import '../../domain/models/avatar_customization.dart';
import '../../domain/models/character.dart';
import '../widgets/character_portrait.dart';

/// バトルスプライトのカスタマイズ画面（アバタースタジオ）
///
/// アクセサリー・色・足元の影の3スロットで、バトル中の見た目を編集する。
/// 変更は即座に保存される。
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
        title: const Text('バトルスプライトのカスタマイズ'),
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
            title: 'アクセサリー',
            icon: Icons.star,
            color: const Color(0xFFFD79A8),
            children: [
              _buildSlotRow(
                label: 'アクセサリー',
                names: battleAccessoryLabels,
                selected: _customization.accessoryIndex,
                previewBuilder: (i) => _preview.copyWith(accessoryIndex: i),
                onSelect: (i) =>
                    _update(_customization.copyWith(accessoryIndex: i)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildAxisCard(
            title: 'カラー',
            icon: Icons.palette,
            color: const Color(0xFFFFD93D),
            children: [
              _buildColorSwatchRow(),
            ],
          ),
          const SizedBox(height: 16),
          _buildAxisCard(
            title: '影',
            icon: Icons.auto_awesome,
            color: const Color(0xFF6C5CE7),
            children: [
              _buildSlotRow(
                label: '影',
                names: const ['なし', '楕円', '細い楕円', 'リング', 'ひし形', '二重楕円'],
                selected: _customization.auraIndex,
                previewBuilder: (i) => _preview.copyWith(auraIndex: i),
                onSelect: (i) =>
                    _update(_customization.copyWith(auraIndex: i)),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPreviewCard() {
    final customized = _customization.visibleCustomizedCount;
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
          CharacterPortrait(
            character: _preview,
            variant: PortraitVariant.battle,
            height: 96,
          ),
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
          const Text(
            'バトル中の見た目',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            customized == 0 ? 'すべておまかせ（元の見た目）' : '$customized/3 設定済み',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _shuffle,
              icon: const Icon(Icons.casino, size: 18),
              label: const Text('ランダム'),
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
          height: 110,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < names.length + 1; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  if (i == 0)
                    _buildOptionTile(
                      name: 'おまかせ',
                      isSelected: selected == AvatarCustomization.unset,
                      character: null,
                      onTap: () => onSelect(AvatarCustomization.unset),
                    )
                  else
                    _buildOptionTile(
                      name: names[i - 1],
                      isSelected: selected == i - 1,
                      character: previewBuilder(i - 1),
                      onTap: () => onSelect(i - 1),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColorSwatchRow() {
    const names = [
      '炎',
      '水',
      '地',
      '風',
      '光',
      '闇',
      '白',
      '黒',
      '金',
      '銀',
      '桃',
      '青緑',
    ];
    final disabled = _preview.accessoryIndex == 0;
    final selected = _customization.colorPaletteIndex;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: Text(
            'カラーリング',
            style: TextStyle(
              color: disabled ? Colors.white38 : Colors.white70,
              fontSize: 13,
            ),
          ),
        ),
        Opacity(
          opacity: disabled ? 0.38 : 1,
          child: IgnorePointer(
            ignoring: disabled,
            child: SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: names.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return _buildSwatchTile(
                      name: 'おまかせ',
                      color: null,
                      isSelected: selected == AvatarCustomization.unset,
                      onTap: () => _update(
                        _customization.copyWith(
                          colorPaletteIndex: AvatarCustomization.unset,
                        ),
                      ),
                    );
                  }
                  final index = i - 1;
                  return _buildSwatchTile(
                    name: names[index],
                    color: battleAccessoryColors[index],
                    isSelected: selected == index,
                    onTap: () => _update(
                      _customization.copyWith(colorPaletteIndex: index),
                    ),
                  );
                },
              ),
            ),
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
              CharacterPortrait(
                character: character,
                variant: PortraitVariant.battle,
                height: 48,
              )
            else
              const SizedBox(
                width: 48,
                height: 48,
                child: Icon(Icons.shuffle, color: Colors.white38, size: 28),
              ),
            const SizedBox(height: 4),
            Text(
              name,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white60,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwatchTile({
    required String name,
    required Color? color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    const selectedColor = Color(0xFF6C5CE7);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
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
            if (color != null)
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white24),
                ),
              )
            else
              const SizedBox(
                width: 28,
                height: 28,
                child: Icon(Icons.shuffle, color: Colors.white38, size: 20),
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
