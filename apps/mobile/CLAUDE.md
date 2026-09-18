# Mobile app (Flutter) — conventions

Read the repo root `CLAUDE.md` and `docs/` first. This file only covers Flutter-specific conventions.

## Structure

```
lib/
  core/        constants, theme, routing, network, storage, audio, animations, error, utils
  features/    auth, home, lobby, game, card_sets, wallet, profile, tutorial, settings
               each feature: data/ (repositories, DTOs) domain/ (models, use-cases) presentation/ (UI + state)
  shared/      widgets, models, extensions used by 2+ features
```

`features/game/presentation/` additionally splits into `screens/ widgets/ animations/ state/` because the game screen is the most complex surface in the app.

Empty leaf folders currently hold a `.gitkeep` placeholder — remove it the moment real content lands there.

## State management

Riverpod, plain providers (no code generation) — keep it that way unless there's a concrete reason to add `riverpod_generator`/`build_runner` friction. This also applies to models: `shared/models/*.dart` are hand-written classes with a `fromJson` factory, not `freezed`/`json_serializable` (those were in the initial scaffold's `pubspec.yaml` but removed before any model was written — don't re-add them without a concrete reason, since it'd mean converting every existing model). One provider file per service/repository, colocated with the class it provides (see `core/network/api_client.dart` and `core/storage/secure_storage_service.dart` for the pattern: the provider lives right below the class it exposes).

Screens that own a WebSocket subscription (`LobbyScreen`, `GameScreen`) are `ConsumerStatefulWidget`s that attach listeners in `initState` and detach them in `dispose` — the socket connection itself is a single app-wide singleton (`socketServiceProvider`), opened by `AuthController` on login/on a valid stored token and closed on logout, never owned by an individual screen.

## Routing

GoRouter, single source of truth in `core/routing/app_router.dart`. It has an auth redirect: logged out → forced to `/login`/`/register`; logged in → forced off those onto `/home`. The redirect re-runs on every `authControllerProvider` change via a small `ChangeNotifier` bridge (`_AuthRefreshNotifier`) — if you add a new provider whose change should also re-evaluate routing, wire it into that same notifier rather than adding a second bridge. Add new screens as routes here, not ad-hoc `Navigator.push` calls.

## Theming

Never hardcode a color, font size, or weight in a widget. Extend `core/theme/app_colors.dart` / `app_text_styles.dart` / `app_theme.dart` instead. Palette and card visual rules are documented in `docs/CARD_DESIGN.md` at the repo root — read it before building the `CricketCard` widget or any card-adjacent UI.

## Real-time client

`core/network/socket_service.dart` wraps `socket_io_client`; it authenticates by putting the JWT in the Socket.IO handshake's `auth: {token}` (matching `GameGateway.handleConnection` on the backend), not a header. Server is authoritative (see root `CLAUDE.md`) — the socket client only ever emits an intent event (`room:subscribe`, `game:subscribe`, `statistic:selected`) and renders whatever `game:state`/`comparison:result`/etc. event the server sends back; it never computes a comparison, shuffle, or coin balance on-device, and never tries to derive who won a stat comparison itself (see `ComparisonOverlay`, which just displays the raw values). Match event names against `apps/backend/src/game/game-events.constants.ts` so both sides stay in sync; if you add an event on one side, add it on the other in the same change.

## Config

`API_BASE_URL` / `WS_URL` are compile-time `--dart-define`s (see `core/constants/app_constants.dart`), defaulting to the Android emulator's `10.0.2.2:3000` for local dev against the backend in `apps/backend`. That default only works for the Android *emulator* — for a real physical device connected over USB, run `adb reverse tcp:3000 tcp:3000` first (forwards the device's own `localhost:3000` to the host machine's backend) and pass `--dart-define=API_BASE_URL=http://localhost:3000 --dart-define=WS_URL=http://localhost:3000`. For Chrome/Windows-desktop targets, same override — `10.0.2.2` means nothing there either.

## Testing

`flutter analyze` and `flutter test` should both stay clean — run them before considering a change done.
