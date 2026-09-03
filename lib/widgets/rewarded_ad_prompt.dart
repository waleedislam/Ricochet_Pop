import 'dart:ui';
import 'package:flutter/material.dart';

/// Shows the pre-ad intro screen Google requires for rewarded interstitial
/// ads: clear messaging about the reward, plus an obvious way to skip it.
/// Returns true if the player chose to watch, false if they skipped or
/// dismissed it.
Future<bool> showRewardedAdPrompt(
  BuildContext context, {
  required int rewardAmount,
}) async {
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierLabel: 'Bonus points',
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, anim, secAnim) => const SizedBox.shrink(),
    transitionBuilder: (context, anim, secAnim, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return Opacity(
        opacity: anim.value.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: 0.88 + 0.12 * curved.value,
          child: Center(child: _RewardedAdPromptCard(rewardAmount: rewardAmount)),
        ),
      );
    },
  );
  return result ?? false;
}

class _RewardedAdPromptCard extends StatelessWidget {
  final int rewardAmount;
  const _RewardedAdPromptCard({required this.rewardAmount});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFC857).withValues(alpha: 0.25),
            blurRadius: 40,
            spreadRadius: -6,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF223449).withValues(alpha: 0.92),
                  const Color(0xFF0F1721).withValues(alpha: 0.96),
                ],
              ),
              border: Border.all(color: const Color(0xFFFFC857).withValues(alpha: 0.3), width: 1.4),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [Color(0xFFFFC857), Color(0xFFFF8C42)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFC857).withValues(alpha: 0.5),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 32),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Bonus Points!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Watch a short ad and get\n+$rewardAmount points added to your score.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(true),
                    icon: const Icon(Icons.play_circle_fill_rounded),
                    label: const Text('Watch & Earn'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFC857),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text(
                    'No thanks',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
