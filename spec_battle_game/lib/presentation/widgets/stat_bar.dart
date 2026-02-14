import 'package:flutter/material.dart';


/// HPバーや経験値バーなど、比率を表示するバーウィジェット
class StatBar extends StatelessWidget {
  final String label;
  final double value;      // 0.0 〜 1.0
  final Color color;
  final Color backgroundColor;
  final String trailingText;
  final double height;

  const StatBar({
    super.key,
    this.label = '',
    this.value = 1.0,
    this.color = Colors.green,
    this.backgroundColor = Colors.grey,
    this.trailingText = '',
    this.height = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          if (label.isNotEmpty)
            SizedBox(
              width: 40,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                ),
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: height,
                  decoration: BoxDecoration(
                    color: backgroundColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(height / 2),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: value.clamp(0.0, 1.0),
                  child: Container(
                    height: height,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color, color.withValues(alpha: 0.7)],
                      ),
                      borderRadius: BorderRadius.circular(height / 2),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.4),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (trailingText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Text(
                trailingText,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white70,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
