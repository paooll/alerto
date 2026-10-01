import 'instrument.dart';

/// Single comparison operand.
enum ConditionType {
  above,
  below,
  crossesAbove,
  crossesBelow,
  bidAbove,
  bidBelow,
  askAbove,
  askBelow,
  changePercentAbove, // price moved more than X% vs ref price
  entersRange,
  leavesRange,
}

/// One condition node. Range conditions use [value2].
class Condition {
  const Condition({
    required this.type,
    this.value,
    this.value2,
    this.referencePrice, // for changePercent conditions
  });

  final ConditionType type;
  final double? value;
  final double? value2;

  /// Reference price captured when the alert was created (for % change).
  final double? referencePrice;

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'value': value,
        'value2': value2,
        'referencePrice': referencePrice,
      };

  factory Condition.fromMap(Map<String, dynamic> map) => Condition(
        type: ConditionType.values
            .firstWhere((t) => t.name == map['type'], orElse: () => ConditionType.above),
        value: (map['value'] as num?)?.toDouble(),
        value2: (map['value2'] as num?)?.toDouble(),
        referencePrice: (map['referencePrice'] as num?)?.toDouble(),
      );
}

/// How conditions are combined.
enum Logic { all, any }

/// One-time vs repeating alerts.
enum AlertMode { once, repeating }

/// A user-created price alert.
class Alert {
  const Alert({
    required this.id,
    required this.userId,
    required this.symbol,
    required this.displayName,
    required this.assetClass,
    required this.conditions,
    required this.logic,
    required this.mode,
    required this.enabled,
    required this.createdAt,
    this.name,
    this.cooldownMinutes = 0,
    this.expiresAt,
    this.lastTriggeredAt,
  });

  final String id;
  final String userId;
  final String symbol;
  final String? name;
  final AssetClass assetClass;
  final List<Condition> conditions;
  final Logic logic;
  final AlertMode mode;

  /// Repeating alerts with cooldownMinutes > 0 won't re-trigger inside the
  /// cooldown window. One-time alerts disable themselves after firing.
  final int cooldownMinutes;

  final bool enabled;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final DateTime? lastTriggeredAt;

  bool get isExpired => expiresAt != null && expiresAt!.isBefore(DateTime.now().toUtc());

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'symbol': symbol,
        'name': name,
        'displayName': displayName,
        'assetClass': assetClass.name,
        'conditions': conditions.map((c) => c.toMap()).toList(),
        'logic': logic.name,
        'mode': mode.name,
        'cooldownMinutes': cooldownMinutes,
        'enabled': enabled,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'expiresAt': expiresAt?.millisecondsSinceEpoch,
        'lastTriggeredAt': lastTriggeredAt?.millisecondsSinceEpoch,
      };

  factory Alert.fromMap(String id, Map<String, dynamic> map) => Alert(
        id: id,
        userId: map['userId'] as String,
        symbol: map['symbol'] as String,
        name: map['name'] as String?,
        displayName: map['displayName'] as String? ?? map['symbol'] as String,
        assetClass: AssetClass.values
            .firstWhere((a) => a.name == map['assetClass'], orElse: () => AssetClass.forex),
        conditions: (map['conditions'] as List<dynamic>? ?? [])
            .map((c) => Condition.fromMap(Map<String, dynamic>.from(c as Map)))
            .toList(),
        logic: Logic.values
            .firstWhere((l) => l.name == map['logic'], orElse: () => Logic.all),
        mode: AlertMode.values
            .firstWhere((m) => m.name == map['mode'], orElse: () => AlertMode.once),
        cooldownMinutes: (map['cooldownMinutes'] as num?)?.toInt() ?? 0,
        enabled: map['enabled'] as bool? ?? true,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
        expiresAt: map['expiresAt'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(map['expiresAt'] as int),
        lastTriggeredAt: map['lastTriggeredAt'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(map['lastTriggeredAt'] as int),
      );
}
