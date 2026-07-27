import 'package:flclashx/common/common.dart';
import 'package:flclashx/enum/enum.dart';
import 'package:flclashx/providers/providers.dart';
import 'package:flclashx/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'widgets/hero_connect.dart';

class DashboardView extends ConsumerStatefulWidget {
  const DashboardView({super.key});

  @override
  ConsumerState<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends ConsumerState<DashboardView> with PageMixin {
  @override
  void initState() {
    super.initState();
    ref.listenManual(
      isCurrentPageProvider(PageLabel.dashboard),
      (previous, next) {
        if (previous != next && next) {
          initPageState();
        }
      },
      fireImmediately: true,
    );
  }

  @override
  Widget? get floatingActionButton => null;

  @override
  List<Widget> get actions => const [];

  @override
  Widget build(BuildContext context) {
    final isRussian = Localizations.localeOf(context).languageCode == 'ru';
    final profile = ref.watch(currentProfileProvider);
    final isRunning = ref.watch(runTimeProvider) != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 980) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: HeroConnect(),
          );
        }

        return SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1320),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(34, 26, 34, 42),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DashboardHeading(
                      isRussian: isRussian,
                      isRunning: isRunning,
                    ),
                    const SizedBox(height: 26),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(
                          child: SizedBox(
                            height: 420,
                            child: HeroConnect(),
                          ),
                        ),
                        const SizedBox(width: 22),
                        SizedBox(
                          width: 330,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 18),
                            child: Column(
                              children: [
                                _ConnectionOverview(
                                  isRussian: isRussian,
                                  isRunning: isRunning,
                                  profileName: profile?.label,
                                ),
                                const SizedBox(height: 14),
                                _QuickRoutes(isRussian: isRussian),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DashboardHeading extends StatelessWidget {
  const _DashboardHeading({
    required this.isRussian,
    required this.isRunning,
  });

  final bool isRussian;
  final bool isRunning;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isRussian
                      ? 'Маршрутизация без рутины'
                      : 'Routing without busywork',
                  style: context.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  isRussian
                      ? 'Приложения, локации и правила — в одном понятном пространстве.'
                      : 'Applications, locations, and rules in one clear workspace.',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: (isRunning ? premiumMint : Colors.white)
                  .withValues(alpha: isRunning ? 0.1 : 0.045),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: (isRunning ? premiumMint : Colors.white)
                    .withValues(alpha: isRunning ? 0.22 : 0.08),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: isRunning
                        ? premiumMint
                        : context.colorScheme.onSurfaceVariant,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isRunning
                      ? (isRussian ? 'Защита активна' : 'Protection active')
                      : (isRussian ? 'Остановлено' : 'Stopped'),
                  style: context.textTheme.labelMedium?.copyWith(
                    color: isRunning
                        ? premiumMint
                        : context.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}

class _ConnectionOverview extends StatelessWidget {
  const _ConnectionOverview({
    required this.isRussian,
    required this.isRunning,
    required this.profileName,
  });

  final bool isRussian;
  final bool isRunning;
  final String? profileName;

  @override
  Widget build(BuildContext context) => RouteXGlassSurface(
        expand: false,
        blur: 28,
        radius: 24,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 19,
                    color: isRunning
                        ? premiumMint
                        : context.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 9),
                  Text(
                    isRussian ? 'Состояние' : 'Overview',
                    style: context.textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _OverviewLine(
                label: isRussian ? 'Профиль' : 'Profile',
                value:
                    profileName ?? (isRussian ? 'Не выбран' : 'Not selected'),
              ),
              const SizedBox(height: 14),
              _OverviewLine(
                label: isRussian ? 'Ядро' : 'Core',
                value: isRunning
                    ? (isRussian ? 'Работает' : 'Running')
                    : (isRussian ? 'Остановлено' : 'Stopped'),
                active: isRunning,
              ),
              const SizedBox(height: 14),
              _OverviewLine(
                label: isRussian ? 'Управление' : 'Control',
                value: isRussian ? 'Автоматические правила' : 'Automatic rules',
              ),
            ],
          ),
        ),
      );
}

class _OverviewLine extends StatelessWidget {
  const _OverviewLine({
    required this.label,
    required this.value,
    this.active = false,
  });

  final String label;
  final String value;
  final bool active;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: context.textTheme.bodyMedium?.copyWith(
                color: active ? premiumMint : null,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );
}

class _QuickRoutes extends StatelessWidget {
  const _QuickRoutes({required this.isRussian});

  final bool isRussian;

  @override
  Widget build(BuildContext context) => RouteXGlassSurface(
        expand: false,
        blur: 28,
        radius: 24,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              _QuickRouteTile(
                icon: Icons.grid_view_rounded,
                title: isRussian ? 'Приложения' : 'Applications',
                subtitle: isRussian
                    ? 'Назначить маршрут в один клик'
                    : 'Choose a route in one click',
                onTap: () =>
                    globalState.appController.toPage(PageLabel.applications),
              ),
              _QuickRouteTile(
                icon: Icons.language_rounded,
                title: isRussian ? 'Локации' : 'Locations',
                subtitle: isRussian
                    ? 'Выбрать лучший сервер'
                    : 'Choose the best server',
                onTap: () =>
                    globalState.appController.toPage(PageLabel.proxies),
              ),
              _QuickRouteTile(
                icon: Icons.swap_horiz_rounded,
                title: isRussian ? 'Подключения' : 'Connections',
                subtitle: isRussian
                    ? 'Посмотреть активный трафик'
                    : 'Inspect active traffic',
                onTap: () =>
                    globalState.appController.toPage(PageLabel.connections),
              ),
            ],
          ),
        ),
      );
}

class _QuickRouteTile extends StatefulWidget {
  const _QuickRouteTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  State<_QuickRouteTile> createState() => _QuickRouteTileState();
}

class _QuickRouteTileState extends State<_QuickRouteTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: RouteXMotion.resolve(context, RouteXMotion.fast),
          curve: RouteXMotion.curve,
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: _hovered
                ? Colors.white.withValues(alpha: 0.055)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            onTap: widget.onTap,
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: premiumMint.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(widget.icon, size: 19, color: premiumMint),
            ),
            title: Text(widget.title),
            subtitle: Text(
              widget.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: AnimatedSlide(
              offset: Offset(_hovered ? 0.12 : 0, 0),
              duration: RouteXMotion.resolve(context, RouteXMotion.fast),
              child: const Icon(Icons.chevron_right_rounded, size: 19),
            ),
          ),
        ),
      );
}
