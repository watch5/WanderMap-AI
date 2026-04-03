import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// 場所のデータモデル
class Place {
  Place({
    String? id,
    required this.title,
    required this.latitude,
    required this.longitude,
    this.notes = '',
    this.visited = false,
    this.rating = 0,
    this.imagePath,
    this.aiTags = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String title;
  final double latitude;
  final double longitude;
  final String notes;
  final bool visited;
  final int rating; // 0-5
  final String? imagePath;
  final List<String> aiTags;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// コピー用ファクトリ
  Place copyWith({
    String? title,
    double? latitude,
    double? longitude,
    String? notes,
    bool? visited,
    int? rating,
    String? imagePath,
    bool clearImage = false,
    List<String>? aiTags,
    DateTime? updatedAt,
  }) {
    return Place(
      id: id,
      title: title ?? this.title,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      notes: notes ?? this.notes,
      visited: visited ?? this.visited,
      rating: rating ?? this.rating,
      imagePath: clearImage ? null : (imagePath ?? this.imagePath),
      aiTags: aiTags ?? this.aiTags,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// JSON からの変換
  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      id: json['id'] as String,
      title: json['title'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      notes: json['notes'] as String? ?? '',
      visited: json['visited'] as bool? ?? false,
      rating: json['rating'] as int? ?? 0,
      imagePath: json['imagePath'] as String?,
      aiTags: (json['aiTags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// JSON への変換
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'latitude': latitude,
      'longitude': longitude,
      'notes': notes,
      'visited': visited,
      'rating': rating,
      'imagePath': imagePath,
      'aiTags': aiTags,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Place && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
