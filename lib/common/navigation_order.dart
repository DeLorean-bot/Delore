import 'dart:async';

import 'package:flclashx/enum/enum.dart';
import 'package:flclashx/models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _navigationOrderKey = 'delore_navigation_order_v1';

const defaultNavigationOrder = <PageLabel>[
  PageLabel.dashboard,
  PageLabel.proxies,
  PageLabel.profiles,
  PageLabel.applications,
  PageLabel.connections,
  PageLabel.resources,
  PageLabel.logs,
  PageLabel.tools,
];

final navigationOrderProvider =
    StateNotifierProvider<NavigationOrderController, List<PageLabel>>(
  (ref) => NavigationOrderController(),
);

class NavigationOrderController extends StateNotifier<List<PageLabel>> {
  NavigationOrderController() : super(defaultNavigationOrder) {
    unawaited(_load());
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getStringList(_navigationOrderKey);
    if (saved == null || saved.isEmpty) return;

    final parsed = <PageLabel>[];
    for (final name in saved) {
      PageLabel? label;
      for (final candidate in PageLabel.values) {
        if (candidate.name == name) {
          label = candidate;
          break;
        }
      }
      if (label != null && !parsed.contains(label)) parsed.add(label);
    }
    for (final label in defaultNavigationOrder) {
      if (!parsed.contains(label)) parsed.add(label);
    }
    state = List.unmodifiable(parsed);
  }

  void reorderVisible(List<PageLabel> visibleOrder) {
    if (visibleOrder.length < 2) return;
    final visible = visibleOrder.toSet();
    final iterator = visibleOrder.iterator;
    final merged = <PageLabel>[];

    for (final label in state) {
      if (visible.contains(label)) {
        iterator.moveNext();
        merged.add(iterator.current);
      } else {
        merged.add(label);
      }
    }
    for (final label in visibleOrder) {
      if (!merged.contains(label)) merged.add(label);
    }
    state = List.unmodifiable(merged);
    unawaited(_save());
  }

  void reset() {
    state = defaultNavigationOrder;
    unawaited(_save());
  }

  Future<void> _save() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _navigationOrderKey,
      state.map((label) => label.name).toList(growable: false),
    );
  }
}

List<NavigationItem> applyNavigationOrder(
  List<NavigationItem> items,
  List<PageLabel> order,
) {
  final positions = <PageLabel, int>{
    for (var index = 0; index < order.length; index++) order[index]: index,
  };
  final result = [...items]..sort(
      (left, right) => (positions[left.label] ?? positions.length)
          .compareTo(positions[right.label] ?? positions.length),
    );
  return result;
}
