import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/network/socket_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/models/room.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/glass_panel.dart';
import '../../../shared/widgets/premium_button.dart';
import '../../auth/domain/auth_controller.dart';
import '../data/rooms_repository.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({required this.code, super.key});
  final String code;

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  Room? _room;
  String? _errorText;
  bool _isBusy = false;

  void Function(dynamic)? _onRoomUpdated;
  void Function(dynamic)? _onGameStarting;

  @override
  void initState() {
    super.initState();
    _load();

    final socket = ref.read(socketServiceProvider);
    socket.emit('room:subscribe', {'roomCode': widget.code});

    _onRoomUpdated = (data) {
      if (!mounted) return;
      setState(() => _room = Room.fromJson(Map<String, dynamic>.from(data as Map)));
    };
    _onGameStarting = (data) {
      if (!mounted) return;
      final gameId = (data as Map)['gameId'] as String;
      context.go('/game/$gameId');
    };
    socket.on('room:updated', _onRoomUpdated!);
    socket.on('game:starting', _onGameStarting!);
  }

  @override
  void dispose() {
    final socket = ref.read(socketServiceProvider);
    if (_onRoomUpdated != null) socket.off('room:updated', _onRoomUpdated);
    if (_onGameStarting != null) socket.off('game:starting', _onGameStarting);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final room = await ref.read(roomsRepositoryProvider).getByCode(widget.code);
      if (mounted) setState(() => _room = room);
    } catch (error) {
      if (mounted) setState(() => _errorText = describeApiError(error));
    }
  }

  Future<void> _toggleReady(bool ready) async {
    setState(() => _isBusy = true);
    try {
      // Apply the response directly instead of waiting on the room:updated
      // broadcast to come back around — the acting player's own client
      // should always reflect their own action immediately and reliably,
      // not depend on their own socket round-tripping the change back to
      // them. This was the actual bug: the HOST's screen (a different
      // socket) picked up the broadcast fine, but the player who just
      // tapped Ready sometimes didn't see their own tap take effect at all.
      final room = await ref.read(roomsRepositoryProvider).setReady(widget.code, ready);
      if (mounted) setState(() => _room = room);
    } catch (error) {
      if (mounted) setState(() => _errorText = describeApiError(error));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _start() async {
    setState(() => _isBusy = true);
    try {
      await ref.read(roomsRepositoryProvider).start(widget.code);
    } catch (error) {
      if (mounted) setState(() => _errorText = describeApiError(error));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authControllerProvider).valueOrNull;
    final room = _room;

    return Scaffold(
      appBar: AppBar(title: Text('Lobby', style: AppTextStyles.title)),
      body: AppBackground(
        child: room == null
            ? Center(
                child: _errorText != null
                    ? Text(_errorText!, style: TextStyle(color: AppColors.danger))
                    : const CircularProgressIndicator(),
              )
            : _LobbyContent(
                room: room,
                currentUserId: currentUser?.id,
                isBusy: _isBusy,
                errorText: _errorText,
                onToggleReady: _toggleReady,
                onStart: _start,
              ),
      ),
    );
  }
}

class _LobbyContent extends StatelessWidget {
  const _LobbyContent({
    required this.room,
    required this.currentUserId,
    required this.isBusy,
    required this.errorText,
    required this.onToggleReady,
    required this.onStart,
  });

  final Room room;
  final String? currentUserId;
  final bool isBusy;
  final String? errorText;
  final Future<void> Function(bool) onToggleReady;
  final Future<void> Function() onStart;

  @override
  Widget build(BuildContext context) {
    final self = room.players.where((p) => p.userId == currentUserId).firstOrNull;
    final isHost = currentUserId != null && room.hostId == currentUserId;
    final everyoneReady = room.players.isNotEmpty && room.players.every((p) => p.isReady);
    final canStart = isHost && room.players.length >= 2 && everyoneReady;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: room.code));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Room code copied')),
                );
              },
              child: GlassPanel(
                padding: const EdgeInsets.symmetric(vertical: 22),
                borderRadius: 20,
                borderColor: AppColors.gold.withValues(alpha: 0.6),
                glowColor: AppColors.gold,
                child: Column(
                  children: [
                    Text('ROOM CODE — TAP TO COPY', style: AppTextStyles.overline),
                    const SizedBox(height: 8),
                    ShaderMask(
                      shaderCallback: (bounds) => AppColors.goldGradient.createShader(bounds),
                      child: Text(
                        room.code,
                        style: AppTextStyles.hero.copyWith(fontSize: 34, letterSpacing: 6, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Icon(Icons.copy, size: 16, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.monetization_on, size: 15, color: AppColors.gold),
                const SizedBox(width: 4),
                Text(
                  room.entryAmount == 0 ? 'FREE ENTRY' : 'ENTRY ${room.entryAmount}',
                  style: AppTextStyles.body,
                ),
                Text('   •   POOL ${room.potentialRewardPool}', style: AppTextStyles.body),
              ],
            ),
            const SizedBox(height: 22),
            Text('${room.currentPlayers} / ${room.maxPlayers} PLAYERS', style: AppTextStyles.overline),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                itemCount: room.players.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final player = room.players[index];
                  final playerIsHost = player.userId == room.hostId;
                  return GlassPanel(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    borderRadius: 14,
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: player.isReady ? AppColors.electricGreen : AppColors.glassBorder,
                              width: 2,
                            ),
                          ),
                          child: CircleAvatar(
                            backgroundColor: AppColors.navyElevated,
                            child: Icon(
                              player.isReady ? Icons.check : Icons.hourglass_empty,
                              color: player.isReady ? AppColors.electricGreen : AppColors.textMuted,
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            player.username,
                            style: AppTextStyles.title.copyWith(color: AppColors.textPrimary),
                          ),
                        ),
                        if (playerIsHost)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.workspace_premium, size: 14, color: AppColors.gold),
                              const SizedBox(width: 4),
                              Text('HOST', style: AppTextStyles.overline.copyWith(color: AppColors.gold)),
                            ],
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (errorText != null) ...[
              Text(errorText!, style: TextStyle(color: AppColors.danger)),
              const SizedBox(height: 8),
            ],
            if (self != null)
              PremiumButton(
                label: self.isReady ? 'Not Ready' : 'Ready',
                icon: self.isReady ? Icons.close : Icons.check_circle_outline,
                variant: self.isReady ? PremiumButtonVariant.danger : PremiumButtonVariant.secondary,
                isLoading: isBusy,
                onPressed: isBusy ? null : () => onToggleReady(!self.isReady),
              ),
            if (isHost) ...[
              const SizedBox(height: 12),
              PremiumButton(
                label: 'Start Game',
                icon: Icons.play_arrow,
                isLoading: isBusy,
                onPressed: (isBusy || !canStart) ? null : onStart,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
