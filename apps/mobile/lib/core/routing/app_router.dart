import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/game/presentation/screens/game_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/lobby/presentation/create_room_screen.dart';
import '../../features/lobby/presentation/join_room_screen.dart';
import '../../features/lobby/presentation/lobby_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/tutorial/presentation/how_to_play_screen.dart';
import '../../features/wallet/presentation/wallet_screen.dart';

const _publicRoutes = {'/login', '/register', '/splash'};

/// Bridges Riverpod state changes into GoRouter's refreshListenable so the
/// redirect below re-runs whenever auth state changes (login/logout), not
/// just on navigation.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen(authControllerProvider, (_, _) => notifyListeners());
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _AuthRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final path = state.matchedLocation;

      if (authState.isLoading) {
        // Only the initial cold-start "checking a stored token" phase should
        // bounce to the splash screen. A login/register submission also sets
        // isLoading (see AuthController.login/register), but forcing a nav
        // away from /login mid-submit unmounts LoginScreen — so if the login
        // call then fails, its `if (state.hasError && mounted)` check is a
        // no-op (mounted is already false), the error never displays, and
        // the user lands back on /login with no explanation. Staying put
        // while already on an auth screen lets it show its own inline
        // spinner/error instead.
        return _publicRoutes.contains(path) ? null : '/splash';
      }

      final loggedIn = authState.valueOrNull != null;
      if (!loggedIn) {
        return _publicRoutes.contains(path) && path != '/splash' ? null : '/login';
      }
      if (_publicRoutes.contains(path)) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(path: '/create-room', builder: (context, state) => const CreateRoomScreen()),
      GoRoute(path: '/join-room', builder: (context, state) => const JoinRoomScreen()),
      GoRoute(
        path: '/lobby/:code',
        builder: (context, state) => LobbyScreen(code: state.pathParameters['code']!),
      ),
      GoRoute(
        path: '/game/:gameId',
        builder: (context, state) => GameScreen(gameId: state.pathParameters['gameId']!),
      ),
      GoRoute(path: '/wallet', builder: (context, state) => const WalletScreen()),
      GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
      GoRoute(path: '/how-to-play', builder: (context, state) => const HowToPlayScreen()),
    ],
  );
});
