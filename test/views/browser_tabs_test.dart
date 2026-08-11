import 'package:flclashx/models/models.dart';
import 'package:flclashx/state.dart';
import 'package:flclashx/views/applications/browser_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('browser tab never renders as an empty page', (tester) async {
    globalState.config = const Config(themeProps: defaultThemeProps);
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: BrowserTabsBody(active: true)),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(BrowserTabsBody), findsOneWidget);
    expect(find.textContaining('extension'), findsWidgets);
  });
}
