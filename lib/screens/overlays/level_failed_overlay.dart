import 'package:flutter/material.dart';

class LevelFailedOverlay extends StatelessWidget {
  const LevelFailedOverlay({
    super.key,
    required this.onRetry,
    required this.onHome,
  });

  final VoidCallback onRetry;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.78),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.close_rounded, color: Color(0xFFFF5C5C), size: 48),
            const SizedBox(height: 10),
            const Text(
              'HAKLAR BİTTİ',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Çok fazla yanlış küp kaldırdın.\nTekrar dene!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 14),
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
                  icon: Icons.refresh_rounded,
                  onTap: onRetry,
                  background: const Color(0xFFFF5C5C),
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
