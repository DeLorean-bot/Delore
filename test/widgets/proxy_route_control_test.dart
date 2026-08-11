import 'package:flclashx/common/common.dart';
import 'package:flclashx/widgets/proxy_route_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('selected proxy location keeps its flag beside the label',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ProxyRouteControl(
              route: ApplicationRoute.proxy,
              routeTarget: '🇸🇪 Sweden',
              onChanged: (_) {},
              onPickLocation: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(
        find.byKey(const ValueKey('selected-location-flag')), findsOneWidget);
    expect(find.text('Sweden'), findsOneWidget);
    expect(find.textContaining('SE Sweden'), findsNothing);
  });
}
