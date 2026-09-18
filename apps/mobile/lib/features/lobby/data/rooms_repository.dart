import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/models/room.dart';

class RoomsRepository {
  RoomsRepository(this._apiClient);
  final ApiClient _apiClient;

  Future<Room> create({
    required String cardSetId,
    required int entryAmount,
    required int maxPlayers,
    int? deckSize,
  }) async {
    final response = await _apiClient.dio.post(
      '/rooms',
      data: {
        'cardSetId': cardSetId,
        'entryAmount': entryAmount,
        'maxPlayers': maxPlayers,
        if (deckSize != null) 'deckSize': deckSize,
      },
    );
    return Room.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Room> getByCode(String code) async {
    final response = await _apiClient.dio.get('/rooms/$code');
    return Room.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Room> join(String code) async {
    final response = await _apiClient.dio.post('/rooms/$code/join');
    return Room.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Room> setReady(String code, bool ready) async {
    final response = await _apiClient.dio.post('/rooms/$code/ready', data: {'ready': ready});
    return Room.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> leave(String code) async {
    await _apiClient.dio.post('/rooms/$code/leave');
  }

  Future<String> start(String code) async {
    final response = await _apiClient.dio.post('/rooms/$code/start');
    return response.data['gameId'] as String;
  }
}

final roomsRepositoryProvider = Provider<RoomsRepository>((ref) {
  return RoomsRepository(ref.watch(apiClientProvider));
});
