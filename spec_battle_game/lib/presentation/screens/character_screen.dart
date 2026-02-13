import 'package:flutter/material.dart';
import '../../domain/models/character.dart';
import '../../domain/enums/element_type.dart';
import '../widgets/pixel_character.dart';
import '../widgets/stat_bar.dart';

/// キャラクター詳細画面
class CharacterScreen extends StatelessWidget {
  final Character character;

  const CharacterScreen({Key key, this.character}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0D1B2A),
      appBar: AppBar(
        title: Text('キャラクター'),
        backgroundColor: Color(0xFF1B2838),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            // キャラクター表示エリア
            _buildCharacterCard(context),
            SizedBox(height: 20),
            // ステータス詳細
            _buildStatsCard(context),
            SizedBox(height: 20),
            // スキル一覧
            _buildSkillsCard(context),
            SizedBox(height: 20),
            // 経験値
            _buildExpCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildCharacterCard(BuildContext context) {
    final elemColor = _getElementColor(character.element);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            elemColor.withOpacity(0.3),
            Color(0xFF1B2838),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: elemColor.withOpacity(0.5), width: 1),
      ),
      child: Column(
        children: [
          PixelCharacter(character: character, size: 160),
          SizedBox(height: 16),
          Text(
            character.name ?? 'Unknown',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _elementBadge(character.element),
              SizedBox(width: 12),
              Text(
                'Lv. ${character.level}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(BuildContext context) {
    final stats = character.currentStats;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF1B2838),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ステータス',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          SizedBox(height: 12),
          StatBar(
            label: 'HP',
            value: stats.hpPercentage,
            color: Colors.greenAccent,
            trailingText: '${stats.hp}/${stats.maxHp}',
            height: 14,
          ),
          SizedBox(height: 8),
          _statRow('ATK', stats.atk, Colors.redAccent, 25),
          _statRow('DEF', stats.def, Colors.blueAccent, 25),
          _statRow('SPD', stats.spd, Colors.orangeAccent, 25),
        ],
      ),
    );
  }

  Widget _statRow(String label, int value, Color color, int maxValue) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: StatBar(
        label: label,
        value: value / maxValue,
        color: color,
        trailingText: '$value',
        height: 12,
      ),
    );
  }

  Widget _buildSkillsCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF1B2838),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('スキル',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          SizedBox(height: 12),
          if (character.skills != null)
            ...character.skills.map((skill) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _skillIcon(skill.category),
                          color: _getElementColor(skill.element),
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(skill.name,
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600)),
                              Text(skill.description,
                                  style: TextStyle(
                                      color: Colors.white54, fontSize: 12)),
                            ],
                          ),
                        ),
                        Text('CT:${skill.cooldown}',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildExpCard(BuildContext context) {
    final exp = character.experience;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF1B2838),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('経験値',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          SizedBox(height: 12),
          StatBar(
            label: 'EXP',
            value: exp?.progressPercentage ?? 0.0,
            color: Color(0xFF6C5CE7),
            trailingText: '${exp?.currentExp ?? 0}/${exp?.expToNext ?? 100}',
            height: 12,
          ),
        ],
      ),
    );
  }

  Widget _elementBadge(ElementType element) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _getElementColor(element).withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: _getElementColor(element).withOpacity(0.6)),
      ),
      child: Text(
        elementName(element),
        style: TextStyle(
          color: _getElementColor(element),
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  IconData _skillIcon(category) {
    switch (category.toString()) {
      case 'SkillCategory.attack':
        return Icons.flash_on;
      case 'SkillCategory.defense':
        return Icons.shield;
      case 'SkillCategory.special':
        return Icons.auto_awesome;
    }
    return Icons.star;
  }

  Color _getElementColor(ElementType element) {
    switch (element) {
      case ElementType.fire:
        return Color(0xFFFF6B6B);
      case ElementType.water:
        return Color(0xFF74B9FF);
      case ElementType.earth:
        return Color(0xFFFDCB6E);
      case ElementType.wind:
        return Color(0xFF55EFC4);
      case ElementType.light:
        return Color(0xFFFFF176);
      case ElementType.dark:
        return Color(0xFFAB47BC);
    }
    return Colors.white;
  }
}
