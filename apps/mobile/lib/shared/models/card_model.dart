import 'player.dart';

/// Named CardModel, not Card, to avoid clashing with Flutter's Material Card.
class CardModel {
  const CardModel({
    required this.id,
    required this.rarity,
    required this.rating,
    required this.imageUrl,
    required this.player,
    required this.statistics,
    this.selectableStatistics = const [],
  });

  final String id;
  final String rarity;
  final int rating;
  final String? imageUrl;
  final Player player;
  final PlayerStatistics statistics;
  final List<String> selectableStatistics;

  factory CardModel.fromJson(Map<String, dynamic> json) => CardModel(
        id: json['id'] as String,
        rarity: json['rarity'] as String,
        rating: json['rating'] as int,
        imageUrl: json['imageUrl'] as String?,
        player: Player.fromJson(json['player'] as Map<String, dynamic>),
        statistics: PlayerStatistics.fromJson(json['statistics'] as Map<String, dynamic>),
        selectableStatistics:
            (json['selectableStatistics'] as List<dynamic>? ?? const []).cast<String>(),
      );
}
