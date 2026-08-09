import 'package:flutter/material.dart';

import '../common/common.dart';

/// Shared Delore empty/loading language: one compact black glass object with
/// a restrained monochrome system indicator. There is no decorative orbit or
/// looping illustration competing with the actual status.
class RouteXStatusState extends StatelessWidget {
  const RouteXStatusState({
    super.key,
    required this.title,
    this.detail,
    this.icon = Icons.radar_rounded,
    this.loading = false,
    this.actions = const [],
  });

  final String title;
  final String? detail;
  final IconData icon;
  final bool loading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final entrance = RouteXMotion.resolve(context, RouteXMotion.base);
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: entrance,
        curve: RouteXMotion.curve,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 6 * (1 - value)),
            child: child,
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: RouteXGlassSurface(
            expand: false,
            variant: RouteXGlassVariant.panel,
            radius: 24,
            tintAlphaFactor: 1,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(30, 26, 30, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 54,
                    height: 54,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.26),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Center(
                        child: loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                  strokeCap: StrokeCap.round,
                                ),
                              )
                            : Icon(icon, size: 23, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 17),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                  ),
                  if (detail != null) ...[
                    const SizedBox(height: 7),
                    Text(
                      detail!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.58),
                            height: 1.45,
                          ),
                    ),
                  ],
                  if (actions.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: actions,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NullStatus extends StatelessWidget {
  const NullStatus({
    super.key,
    required this.label,
    this.detail,
    this.icon = Icons.radar_rounded,
  });

  final String label;
  final String? detail;
  final IconData icon;

  @override
  Widget build(BuildContext context) => RouteXStatusState(
        title: label,
        detail: detail,
        icon: icon,
      );
}
