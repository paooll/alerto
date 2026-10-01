import '../domain/alert.dart';

/// Human-readable summary of one condition, e.g. "Price above 1.0850".
String describeCondition(Condition c) {
  final v = c.value;
  final v2 = c.value2;
  switch (c.type) {
    case ConditionType.above:
      return 'Price above ${v ?? '?'}';
    case ConditionType.below:
      return 'Price below ${v ?? '?'}';
    case ConditionType.crossesAbove:
      return 'Price crosses above ${v ?? '?'}';
    case ConditionType.crossesBelow:
      return 'Price crosses below ${v ?? '?'}';
    case ConditionType.bidAbove:
      return 'Bid ≥ ${v ?? '?'}';
    case ConditionType.bidBelow:
      return 'Bid ≤ ${v ?? '?'}';
    case ConditionType.askAbove:
      return 'Ask ≥ ${v ?? '?'}';
    case ConditionType.askBelow:
      return 'Ask ≤ ${v ?? '?'}';
    case ConditionType.changePercentAbove:
      return 'Change ≥ ${v ?? '?'}% (ref ${c.referencePrice ?? '—'})';
    case ConditionType.entersRange:
      return 'Enters ${v ?? '?'} – ${v2 ?? '?'}';
    case ConditionType.leavesRange:
      return 'Leaves ${v ?? '?'} – ${v2 ?? '?'}';
  }
}

String describeConditions(List<Condition> conditions) {
  if (conditions.isEmpty) return 'No conditions';
  if (conditions.length == 1) return describeCondition(conditions.first);
  return conditions.map(describeCondition).join(' · ');
}
