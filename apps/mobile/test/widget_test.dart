import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:card_cricket/core/storage/secure_storage_service.dart';
import 'package:card_cricket/main.dart';

/// No real secure-storage plugin exists in a widget test — this keeps
/// AuthController.build() from touching a platform channel at all.
class _FakeSecureStorageService extends SecureStorageService {
  String? _token;

  @override
  Future<void> saveAuthToken(String token) async => _token = token;

  @override
  Future<String?> readAuthToken() async => _token;

  @override
  Future<void> clearAuthToken() async => _token = null;
}

void main() {
  testWidgets('A logged-out app boots to the login screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [secureStorageServiceProvider.overrideWithValue(_FakeSecureStorageService())],
        child: const CardCricketApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CARD CRICKET'), findsOneWidget);
    expect(find.text('LOG IN'), findsOneWidget);
  });
}
