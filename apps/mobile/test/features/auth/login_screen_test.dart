import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:card_cricket/core/storage/secure_storage_service.dart';
import 'package:card_cricket/features/auth/presentation/login_screen.dart';

/// No real secure-storage plugin exists in a widget test — this keeps
/// AuthController.build() from touching a platform channel at all, so the
/// screen settles to its logged-out state instead of staying in AsyncLoading.
class _FakeSecureStorageService extends SecureStorageService {
  @override
  Future<String?> readAuthToken() async => null;
}

void main() {
  testWidgets('LoginScreen validates email and password before submitting', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [secureStorageServiceProvider.overrideWithValue(_FakeSecureStorageService())],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('LOG IN'));
    await tester.pump();

    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(find.text('At least 8 characters'), findsOneWidget);
  });
}
