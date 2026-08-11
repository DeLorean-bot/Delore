class VisualRoutingPlan {
  const VisualRoutingPlan({
    required this.coreMode,
    required this.rules,
    required this.emulatesGlobal,
  });

  final String coreMode;
  final List<String> rules;
  final bool emulatesGlobal;
}

/// Produces the rule order that the core must actually receive.
///
/// Mihomo's native `global` mode skips the rule engine completely. Delore
/// therefore emulates global mode whenever visual app/site exceptions exist:
/// exceptions are evaluated first and every remaining connection falls
/// through to the currently selected member of GLOBAL.
VisualRoutingPlan buildVisualRoutingPlan({
  required String requestedMode,
  required List<String> domainRules,
  required List<String> applicationRules,
  required List<dynamic> providerRules,
}) {
  final customRules = <String>[...domainRules, ...applicationRules];
  final emulateGlobal = requestedMode == 'global' && customRules.isNotEmpty;
  if (emulateGlobal) {
    return VisualRoutingPlan(
      coreMode: 'rule',
      rules: [...customRules, 'MATCH,GLOBAL'],
      emulatesGlobal: true,
    );
  }
  return VisualRoutingPlan(
    coreMode: requestedMode,
    rules: [...customRules, ...providerRules.map((rule) => rule.toString())],
    emulatesGlobal: false,
  );
}
