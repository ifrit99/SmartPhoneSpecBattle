import 'package:flutter/material.dart';
import '../../domain/enums/battle_tactic.dart';
import '../../domain/enums/rarity.dart';
import '../../domain/models/character.dart';
import '../../domain/services/qr_battle_service.dart';
import '../../domain/services/service_locator.dart';
import '../../domain/services/character_generator.dart';
import '../../data/device_info_service.dart';
import '../../data/sound_service.dart';
import '../../domain/enums/element_type.dart';
import '../theme/app_colors.dart';
import '../widgets/pixel_character.dart';
import '../widgets/stat_bar.dart';
import 'battle_screen.dart';
import 'collection_screen.dart';
import 'gacha_screen.dart';
import 'qr_menu_screen.dart';

/// URLから読み取ったゲストキャラクターのプレビュー画面
class QrGuestPreviewScreen extends StatefulWidget {
  final QrBattleGuest guest;

  /// フレンドメニュー経由で遷移してきたかどうか
  /// true の場合、friend選択時はpopで既存メニューに戻る
  final bool fromFriendMenu;

  const QrGuestPreviewScreen({
    super.key,
    required this.guest,
    this.fromFriendMenu = false,
  });

  @override
  State<QrGuestPreviewScreen> createState() => _QrGuestPreviewScreenState();
}

class _QrGuestPreviewScreenState extends State<QrGuestPreviewScreen> {
  bool _loading = false;
  late final Future<Character> _playerFuture;
  BattleTactic? _selectedTactic;

  @override
  void initState() {
    super.initState();
    _playerFuture = _getEquippedPlayer().then((player) {
      final recommended = _MatchupAnalysis(player, widget.guest.battleCharacter)
          .recommendedTactic;
      if (mounted) {
        setState(() => _selectedTactic ??= recommended);
      } else {
        _selectedTactic ??= recommended;
      }
      return player;
    });
  }

  void _startBattle() async {
    setState(() => _loading = true);
    SoundService().playButton();

    late final Character player;
    try {
      player = await _playerFuture;
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('自分のキャラクターを読み込めませんでした')),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _loading = false);
    final tactic = _selectedTactic ??
        _MatchupAnalysis(player, widget.guest.battleCharacter)
            .recommendedTactic;

    final nextAction = await Navigator.of(context).push<String?>(
      MaterialPageRoute(
        builder: (context) => BattleScreen(
          player: player,
          enemy: widget.guest.battleCharacter,
          enemyDeviceId: null,
          isCpuBattle: false,
          playerTactic: tactic,
        ),
      ),
    );

    if (!mounted) return;

    // 初回バトル後の案内アクションを処理
    if (nextAction == 'gacha') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const GachaScreen()),
      );
    } else if (nextAction == 'achievements') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => CollectionScreen(
            playerCharacter: player,
            initialTabIndex: 2,
          ),
        ),
      );
    } else if (nextAction == 'friend') {
      if (widget.fromFriendMenu) {
        // フレンドメニュー経由：既存のFriendBattleMenuScreenへpopで戻る
        Navigator.of(context).pop();
      } else {
        // ディープリンク経由：FriendBattleMenuScreenへ遷移
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
              builder: (context) => const FriendBattleMenuScreen()),
        );
      }
    } else {
      // 通常のバトル終了：プレビュー画面を閉じて前の画面に戻る
      Navigator.of(context).pop();
    }
  }

  Future<Character> _getEquippedPlayer() async {
    final sl = ServiceLocator();
    final equippedId = sl.storage.getEquippedGachaCharacterId();

    if (equippedId != null) {
      final equipped = sl.gachaService.findById(equippedId);
      if (equipped != null) {
        return equipped.character;
      }
    }

    // ガチャキャラ未装備の場合は実機スペックからキャラ生成
    final deviceInfo = DeviceInfoService();
    final specs = await deviceInfo.getDeviceSpecs();
    final exp = sl.experienceService.loadExperience();
    return CharacterGenerator.generate(specs, experience: exp);
  }

  @override
  Widget build(BuildContext context) {
    final enemy = widget.guest.battleCharacter;
    final elemColor = elementColor(enemy.element);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(title: const Text('対戦プレビュー')),
      body: SafeArea(
        child: FutureBuilder<Character>(
          future: _playerFuture,
          builder: (context, snapshot) {
            final player = snapshot.data;
            final loadingPlayer =
                snapshot.connectionState != ConnectionState.done;
            final matchup =
                player == null ? null : _MatchupAnalysis(player, enemy);

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildGuestHeader(enemy, elemColor),
                  const SizedBox(height: 18),
                  _buildVersusCard(
                    player: player,
                    enemy: enemy,
                    elemColor: elemColor,
                    loadingPlayer: loadingPlayer,
                  ),
                  const SizedBox(height: 16),
                  if (matchup != null) ...[
                    _buildMatchupCard(matchup),
                    const SizedBox(height: 16),
                    _buildTacticSelector(matchup),
                    const SizedBox(height: 16),
                  ] else if (snapshot.hasError) ...[
                    _buildLoadErrorCard(),
                    const SizedBox(height: 16),
                  ],
                  _buildEnemyStats(enemy),
                  const SizedBox(height: 24),
                  _buildBattleButton(
                      enabled: !loadingPlayer && !snapshot.hasError),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed:
                        _loading ? null : () => Navigator.of(context).pop(),
                    child: const Text(
                      'キャンセル',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGuestHeader(Character enemy, Color elemColor) {
    final rarityLabel = widget.guest.rarity?.label;
    final sourceLabel = widget.guest.isGacha ? 'ガチャキャラ' : '実機スペック';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF12263A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: elemColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: elemColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: elemColor.withValues(alpha: 0.35)),
            ),
            child: Icon(Icons.link, color: elemColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  enemy.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _infoPill(sourceLabel, Colors.white70),
                    if (rarityLabel != null) _infoPill(rarityLabel, elemColor),
                    _infoPill(elementName(enemy.element), elemColor),
                    _infoPill('Lv.${enemy.level}', Colors.white70),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVersusCard({
    required Character? player,
    required Character enemy,
    required Color elemColor,
    required bool loadingPlayer,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF172A45), Color(0xFF111F33)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _fighterColumn(
              label: 'YOU',
              character: player,
              color: Colors.cyanAccent,
              loading: loadingPlayer,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              children: [
                const Text(
                  'VS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 42,
                  height: 2,
                  color: Colors.white.withValues(alpha: 0.18),
                ),
              ],
            ),
          ),
          Expanded(
            child: _fighterColumn(
              label: 'GUEST',
              character: enemy,
              color: elemColor,
              loading: false,
              flip: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fighterColumn({
    required String label,
    required Character? character,
    required Color color,
    required bool loading,
    bool flip = false,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 102,
          child: loading
              ? const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white54,
                  ),
                )
              : character == null
                  ? const Icon(Icons.error_outline,
                      color: Colors.redAccent, size: 42)
                  : PixelCharacter(
                      character: character,
                      size: 96,
                      flipHorizontal: flip,
                    ),
        ),
        const SizedBox(height: 8),
        Text(
          character?.name ?? '読み込み中',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          character == null
              ? ''
              : '${elementName(character.element)} / Lv.${character.level}',
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildMatchupCard(_MatchupAnalysis matchup) {
    final accent = matchup.isFavorable
        ? Colors.greenAccent
        : matchup.isClose
            ? Colors.amberAccent
            : Colors.redAccent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF12263A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_outlined, color: accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  matchup.title,
                  style: TextStyle(
                    color: accent,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _scoreBlock(
                  label: '自分',
                  score: matchup.playerScore,
                  color: Colors.cyanAccent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _scoreBlock(
                  label: '相手',
                  score: matchup.enemyScore,
                  color: Colors.pinkAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            matchup.detail,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.bolt, color: accent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '推奨: ${matchup.recommendedTactic.label}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTacticSelector(_MatchupAnalysis matchup) {
    final selected = _selectedTactic ?? matchup.recommendedTactic;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF102033),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune, size: 18, color: Colors.white54),
              SizedBox(width: 8),
              Text(
                '戦術',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: BattleTactic.values.map((tactic) {
              final isSelected = tactic == selected;
              final isRecommended = tactic == matchup.recommendedTactic;
              return ChoiceChip(
                selected: isSelected,
                onSelected: (_) {
                  SoundService().playButton();
                  setState(() => _selectedTactic = tactic);
                },
                label: Text(
                  isRecommended ? '${tactic.label} 推奨' : tactic.label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                avatar: isSelected
                    ? const Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 16,
                      )
                    : null,
                selectedColor: const Color(0xFF6C5CE7),
                backgroundColor: Colors.white.withValues(alpha: 0.05),
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFF6C5CE7)
                      : Colors.white.withValues(alpha: 0.12),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Text(
            selected.description,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreBlock({
    required String label,
    required int score,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 11)),
          const SizedBox(height: 3),
          Text(
            '$score',
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadErrorCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: const Text(
        '自分のキャラクターを読み込めませんでした。端末情報を取得できる状態で再度お試しください。',
        style: TextStyle(color: Colors.white70, fontSize: 13),
      ),
    );
  }

  Widget _buildEnemyStats(Character enemy) {
    final stats = enemy.battleStats;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF102033),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '相手ステータス',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          StatBar(
            label: 'HP',
            value: stats.hp / 180,
            color: Colors.greenAccent,
            trailingText: '${stats.hp}',
            height: 8,
          ),
          StatBar(
            label: 'ATK',
            value: stats.atk / 150,
            color: Colors.redAccent,
            trailingText: '${stats.atk}',
            height: 8,
          ),
          StatBar(
            label: 'DEF',
            value: stats.def / 150,
            color: Colors.blueAccent,
            trailingText: '${stats.def}',
            height: 8,
          ),
          StatBar(
            label: 'SPD',
            value: stats.spd / 150,
            color: Colors.amberAccent,
            trailingText: '${stats.spd}',
            height: 8,
          ),
        ],
      ),
    );
  }

  Widget _buildBattleButton({required bool enabled}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _loading || !enabled ? null : _startBattle,
        icon: _loading
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.sports_mma, color: Colors.white),
        label: Text(
          _loading ? '準備中...' : 'バトル開始',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6C5CE7),
          disabledBackgroundColor: Colors.white12,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
      ),
    );
  }

  Widget _infoPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _MatchupAnalysis {
  final Character player;
  final Character enemy;

  _MatchupAnalysis(this.player, this.enemy);

  int get playerScore => _battleScore(player, enemy).round();
  int get enemyScore => _battleScore(enemy, player).round();
  int get scoreDiff => playerScore - enemyScore;
  bool get isFavorable => scoreDiff >= 12;
  bool get isClose => scoreDiff.abs() < 12;

  String get title {
    if (isFavorable) return '優勢マッチ';
    if (isClose) return '接戦マッチ';
    return '格上チャレンジ';
  }

  String get detail {
    final playerElement = player.element.multiplierAgainst(enemy.element);
    if (scoreDiff <= -12) {
      if (playerElement > 1.0) {
        return '総合力では相手が上です。属性有利を活かしつつ、被ダメージを抑える戦い方が安定します。';
      }
      return '総合力では相手が上です。まずは耐久寄りに入り、スキル発動で逆転を狙う組み合わせです。';
    }
    if (playerElement > 1.0) {
      return '属性相性で有利です。攻め切れる可能性が高いので、序盤からHPを削りに行けます。';
    }
    if (playerElement < 1.0) {
      return '属性相性は不利です。耐久かスキル発動で流れを作ると勝ち筋が残ります。';
    }
    if (player.battleStats.spd >= enemy.battleStats.spd + 10) {
      return '速度で先手を取りやすい相手です。短期決着を狙うと押し込みやすくなります。';
    }
    if (player.battleStats.def >= enemy.battleStats.atk) {
      return '防御で受けられる相手です。長期戦に寄せると安定しやすくなります。';
    }
    return '総合力は近い相手です。ステータス差より戦術選択が結果に出やすい組み合わせです。';
  }

  BattleTactic get recommendedTactic {
    if (scoreDiff <= -12) {
      return BattleTactic.firewall;
    }
    if (player.element.multiplierAgainst(enemy.element) < 1.0) {
      return BattleTactic.firewall;
    }
    if (player.battleStats.atk >= enemy.battleStats.def + 12) {
      return BattleTactic.overclock;
    }
    if (player.skills.length >= enemy.skills.length) {
      return BattleTactic.burst;
    }
    return BattleTactic.balanced;
  }

  static double _battleScore(Character attacker, Character defender) {
    final stats = attacker.battleStats;
    final element = attacker.element.multiplierAgainst(defender.element);
    return (stats.hp * 0.22) +
        (stats.atk * 0.36 * element) +
        (stats.def * 0.24) +
        (stats.spd * 0.18);
  }
}
