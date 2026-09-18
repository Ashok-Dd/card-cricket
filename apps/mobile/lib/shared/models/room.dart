class RoomPlayerInfo {
  const RoomPlayerInfo({
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.isReady,
  });

  final String userId;
  final String username;
  final String? avatarUrl;
  final bool isReady;

  factory RoomPlayerInfo.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    return RoomPlayerInfo(
      userId: json['userId'] as String,
      username: user['username'] as String,
      avatarUrl: user['avatarUrl'] as String?,
      isReady: json['isReady'] as bool,
    );
  }
}

class Room {
  const Room({
    required this.id,
    required this.code,
    required this.hostId,
    required this.cardSetId,
    required this.entryAmount,
    required this.maxPlayers,
    required this.deckSize,
    required this.status,
    required this.players,
    required this.currentPlayers,
    required this.potentialRewardPool,
  });

  final String id;
  final String code;
  final String hostId;
  final String cardSetId;
  final int entryAmount;
  final int maxPlayers;
  // Null means "every eligible card in the set" (no deck-size limit chosen).
  final int? deckSize;
  final String status;
  final List<RoomPlayerInfo> players;
  final int currentPlayers;
  final int potentialRewardPool;

  factory Room.fromJson(Map<String, dynamic> json) => Room(
        id: json['id'] as String,
        code: json['code'] as String,
        hostId: json['hostId'] as String,
        cardSetId: json['cardSetId'] as String,
        entryAmount: json['entryAmount'] as int,
        maxPlayers: json['maxPlayers'] as int,
        deckSize: json['deckSize'] as int?,
        status: json['status'] as String,
        players: (json['players'] as List<dynamic>)
            .map((p) => RoomPlayerInfo.fromJson(p as Map<String, dynamic>))
            .toList(),
        currentPlayers: json['currentPlayers'] as int,
        potentialRewardPool: json['potentialRewardPool'] as int,
      );
}
