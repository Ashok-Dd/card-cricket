import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/models/card_model.dart';
import '../../../shared/models/card_set.dart';

class CardSetsRepository {
  CardSetsRepository(this._apiClient);
  final ApiClient _apiClient;

  Future<List<CardSet>> getEnabled() async {
    final response = await _apiClient.dio.get('/card-sets');
    return (response.data as List<dynamic>)
        .map((json) => CardSet.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<List<CardModel>> getCards(String code) async {
    final response = await _apiClient.dio.get('/card-sets/$code/cards');
    return (response.data as List<dynamic>)
        .map((json) => CardModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}

final cardSetsRepositoryProvider = Provider<CardSetsRepository>((ref) {
  return CardSetsRepository(ref.watch(apiClientProvider));
});

final enabledCardSetsProvider = FutureProvider.autoDispose<List<CardSet>>((ref) {
  return ref.watch(cardSetsRepositoryProvider).getEnabled();
});
