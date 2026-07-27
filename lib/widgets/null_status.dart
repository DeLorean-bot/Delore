import 'package:flutter/material.dart';

import '../common/common.dart';

class NullStatus extends StatelessWidget {
  const NullStatus({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration:
            reduceMotion ? Duration.zero : const Duration(milliseconds: 360),
        curve: RouteXMotion.curve,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - value)),
            child: child,
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: RouteXGlassSurface(
            expand: false,
            radius: 28,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(34, 30, 34, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          premiumMint.withValues(alpha: 0.22),
                          premiumBlue.withValues(alpha: 0.14),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: const Icon(
                      Icons.route_rounded,
                      color: premiumMint,
                      size: 27,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: 36,
                    height: 3,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      gradient: const LinearGradient(
                        colors: [premiumMint, premiumBlue],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
