/// The kind of equipment an activity is recorded with.
enum GearType {
  /// A bicycle. Distance accumulates over every ride.
  bicycle,

  /// A pair of shoes. Distance accumulates over every run.
  shoe;

  /// Human readable label.
  String get label => switch (this) {
        GearType.bicycle => 'Bicycle',
        GearType.shoe => 'Shoes',
      };

  /// Parses a [GearType] from its database representation.
  static GearType fromStorage(String value) => GearType.values.firstWhere(
        (type) => type.name == value,
        orElse: () => GearType.bicycle,
      );
}

/// A piece of equipment (bicycle, running shoes, ...) that activities are
/// attributed to.
class Gear {
  /// Database identifier. `null` for gear that has not been persisted yet.
  final int? id;

  /// Display name, e.g. "Gravel bike" or "Pegasus 40".
  final String name;

  /// Manufacturer, e.g. "Specialized".
  final String? brand;

  /// Model name, e.g. "Diverge E5".
  final String? model;

  /// Equipment category.
  final GearType type;

  /// Total distance accumulated on this gear (metres).
  final double totalDistanceMeters;

  /// Whether this gear is pre-selected when starting a recording.
  final bool isDefault;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Last modification timestamp.
  final DateTime updatedAt;

  const Gear({
    this.id,
    required this.name,
    this.brand,
    this.model,
    this.type = GearType.bicycle,
    this.totalDistanceMeters = 0,
    this.isDefault = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Builds a gear from a database row.
  factory Gear.fromMap(Map<String, Object?> map) {
    return Gear(
      id: map['id'] as int?,
      name: (map['name'] as String?) ?? '',
      brand: map['brand'] as String?,
      model: map['model'] as String?,
      type: GearType.fromStorage((map['type'] as String?) ?? 'bicycle'),
      totalDistanceMeters: (map['total_distance_meters'] as num?)?.toDouble() ?? 0,
      isDefault: ((map['is_default'] as int?) ?? 0) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch((map['created_at'] as int?) ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch((map['updated_at'] as int?) ?? 0),
    );
  }

  /// Converts the gear into a database row.
  Map<String, Object?> toMap() => <String, Object?>{
        if (id != null) 'id': id,
        'name': name,
        'brand': brand,
        'model': model,
        'type': type.name,
        'total_distance_meters': totalDistanceMeters,
        'is_default': isDefault ? 1 : 0,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  /// Returns a copy with the given fields replaced.
  Gear copyWith({
    int? id,
    String? name,
    String? brand,
    String? model,
    GearType? type,
    double? totalDistanceMeters,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Gear(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      type: type ?? this.type,
      totalDistanceMeters: totalDistanceMeters ?? this.totalDistanceMeters,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// A short "brand model" description, falling back to the name.
  String get subtitle {
    final parts = <String>[
      if (brand != null && brand!.isNotEmpty) brand!,
      if (model != null && model!.isNotEmpty) model!,
    ];
    return parts.isEmpty ? name : parts.join(' ');
  }
}
