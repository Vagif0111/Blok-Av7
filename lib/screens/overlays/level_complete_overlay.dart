import 'package:flutter/material.dart';

class LevelCompleteOverlay extends StatelessWidget {
  const LevelCompleteOverlay({
    super.key,
    required this.level,
    required this.onNextLevel,
    required this.onHome,
  });

  final int level;
  final VoidCallback onNextLevel;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.75),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 48),
            const SizedBox(height: 10),
            const Text(
              'SEVİYE TAMAMLANDI!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Seviye $level tamamlandı',
              style: const TextStyle(color: Colors.white60, fontSize: 14),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _RoundButton(
                  icon: Icons.home_rounded,
                  onTap: onHome,
                  background: const Color(0xFF1B1F35),
                ),
                const SizedBox(width: 20),
                _RoundButton(
                  icon: Icons.arrow_forward_rounded,
                  onTap: onNextLevel,
                  background: const Color(0xFF00F5FF),
                  large: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.onTap,
    required this.background,
    this.large = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color background;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final size = large ? 64.0 : 52.0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size / 2),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: large ? 30 : 24),
      ),
    );
  }
}
