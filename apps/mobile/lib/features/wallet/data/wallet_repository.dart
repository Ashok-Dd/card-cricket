import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/models/wallet.dart';

class WalletRepository {
  WalletRepository(this._apiClient);
  final ApiClient _apiClient;

  Future<Wallet> getWallet() async {
    final response = await _apiClient.dio.get('/wallet');
    return Wallet.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<CoinTransaction>> getTransactions() async {
    final response = await _apiClient.dio.get('/wallet/transactions');
    return (response.data as List<dynamic>)
        .map((json) => CoinTransaction.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository(ref.watch(apiClientProvider));
});

final walletProvider = FutureProvider.autoDispose<Wallet>((ref) {
  return ref.watch(walletRepositoryProvider).getWallet();
});

final walletTransactionsProvider = FutureProvider.autoDispose<List<CoinTransaction>>((ref) {
  return ref.watch(walletRepositoryProvider).getTransactions();
});
