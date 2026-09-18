/// Loose passthrough for a card's batting/bowling numbers — the exact set of
/// fields varies per card set (see CardSet.statSchema), so this stays a map
/// with typed accessors rather than a fixed list of nullable fields.
class PlayerStatistics {
  const PlayerStatistics(this.raw);

  final Map<String, dynamic> raw;

  num? numeric(String field) => raw[field] is num ? raw[field] as num : null;
  String? get bestBowling => raw['bestBowling'] as String?;
  DateTime? get dateOfBirth =>
      raw['dateOfBirth'] != null ? DateTime.parse(raw['dateOfBirth'] as String) : null;

  factory PlayerStatistics.fromJson(Map<String, dynamic> json) => PlayerStatistics(json);
}

class Player {
  const Player({
    required this.id,
    required this.name,
    required this.displayName,
    required this.country,
    required this.role,
    this.team,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String displayName;
  final String country;
  final String role;
  final String? team;
  final String? imageUrl;

  factory Player.fromJson(Map<String, dynamic> json) => Player(
        id: json['id'] as String,
        name: json['name'] as String,
        displayName: json['displayName'] as String,
        country: json['country'] as String,
        role: json['role'] as String,
        team: json['team'] as String?,
        imageUrl: json['imageUrl'] as String?,
      );
}
