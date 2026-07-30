import 'package:flclashx/common/common.dart';
import 'package:flclashx/enum/enum.dart';
import 'package:flclashx/providers/providers.dart';
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
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: HeroConnect(),
    );
  }
}
