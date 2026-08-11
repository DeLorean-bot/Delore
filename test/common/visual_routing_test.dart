import 'package:flclashx/common/visual_routing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('site routes win while the UI is in global mode', () {
    final plan = buildVisualRoutingPlan(
      requestedMode: 'global',
      domainRules: const ['DOMAIN-SUFFIX,example.com,Netherlands'],
      applicationRules: const [],
      providerRules: const ['MATCH,Provider'],
    );

    expect(plan.coreMode, 'rule');
    expect(plan.emulatesGlobal, isTrue);
    expect(plan.rules, const [
      'DOMAIN-SUFFIX,example.com,Netherlands',
      'MATCH,GLOBAL',
    ]);
  });

  test('rule mode keeps visual routes ahead of provider rules', () {
    final plan = buildVisualRoutingPlan(
      requestedMode: 'rule',
      domainRules: const ['DOMAIN-SUFFIX,example.com,Netherlands'],
      applicationRules: const ['PROCESS-PATH,browser.exe,India'],
      providerRules: const ['MATCH,Provider'],
    );

    expect(plan.coreMode, 'rule');
    expect(plan.emulatesGlobal, isFalse);
    expect(plan.rules, const [
      'DOMAIN-SUFFIX,example.com,Netherlands',
      'PROCESS-PATH,browser.exe,India',
      'MATCH,Provider',
    ]);
  });
}
