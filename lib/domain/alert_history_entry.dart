import 'condition.dart';

/// One triggered-alert record, written by the backend evaluator into
/// users/{uid}/alertHistory.
class AlertHistoryEntry {
  const AlertHistoryEntry({
    required this.id,
    required this.alertId,
    required this.symbol,
    required this.price,
    required this.triggeredAt,
    this.alertName,
    this.conditions = const [],
    this.mode,
  });

  final String id;

  /// The alert may have been deleted since firing; keep the id for reference.
  final String alertId;
  final String? alertName;
  final String symbol;
  final List<Condition> conditions;
  final String? mode;

  /// Price at trigger time.
  final double price;
  final DateTime triggeredAt;

  static AlertHistoryEntry fromMap(String id, Map<String, dynamic> map) {
    return AlertHistoryEntry(
      id: id,
      alertId: map['alertId'] as String? ?? '',
      alertName: map['alertName'] as String?,
      symbol: map['symbol'] as String? ?? '',
      conditions: (map['conditions'] as List<dynamic>? ?? const [])
          .map((c) => Condition.fromMap(Map<String, dynamic>.from(c as Map)))
          .toList(),
      mode: map['mode'] as String?,
      price: (map['price'] as num?)?.toDouble() ?? 0,
      triggeredAt: map['triggeredAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['triggeredAt'] as int, isUtc: true)
          : (map['triggeredAt'] as DateTime? ?? DateTime.now().toUtc()),
    );
  }
}
