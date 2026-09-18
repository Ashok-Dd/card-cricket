import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/models/card_set.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/glass_panel.dart';
import '../../../shared/widgets/premium_button.dart';
import '../../card_sets/data/card_sets_repository.dart';
import '../data/rooms_repository.dart';

const _entryTiers = [0, 100, 500, 1000, 5000];
// null means "every eligible card in the set" — the server validates
// whichever size is chosen against the set's real card count at creation
// time, so this stays a plain fixed list rather than needing a live count.
const _deckSizeOptions = <int?>[50, 100, 200, null];

class CreateRoomScreen extends ConsumerStatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  ConsumerState<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends ConsumerState<CreateRoomScreen> {
  CardSet? _selectedCardSet;
  int _entryAmount = 0;
  int _maxPlayers = 4;
  int? _deckSize; // null = every eligible card in the set
  bool _isSubmitting = false;
  String? _errorText;

  Future<void> _submit() async {
    final cardSet = _selectedCardSet;
    if (cardSet == null) {
      setState(() => _errorText = 'Choose a card set first');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      final room = await ref.read(roomsRepositoryProvider).create(
            cardSetId: cardSet.id,
            entryAmount: _entryAmount,
            maxPlayers: _maxPlayers,
            deckSize: _deckSize,
          );
      if (mounted) context.go('/lobby/${room.code}');
    } catch (error) {
      if (mounted) setState(() => _errorText = describeApiError(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardSetsAsync = ref.watch(enabledCardSetsProvider);
    final potentialPool = _entryAmount * _maxPlayers;

    return Scaffold(
      appBar: AppBar(title: Text('Create Room', style: AppTextStyles.title)),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('CARD SET', style: AppTextStyles.overline),
            const SizedBox(height: 10),
            cardSetsAsync.when(
              data: (cardSets) => SizedBox(
                height: 84,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: cardSets.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final cardSet = cardSets[index];
                    final selected = _selectedCardSet?.id == cardSet.id;
                    return _CardSetTile(
                      cardSet: cardSet,
                      selected: selected,
                      onTap: () => setState(() => _selectedCardSet = cardSet),
                    );
                  },
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text('Could not load card sets', style: AppTextStyles.body),
            ),
            const SizedBox(height: 26),
            Text('ENTRY', style: AppTextStyles.overline),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _entryTiers.map((amount) {
                final selected = _entryAmount == amount;
                return _EntryChip(
                  amount: amount,
                  selected: selected,
                  onTap: () => setState(() => _entryAmount = amount),
                );
              }).toList(),
            ),
            const SizedBox(height: 26),
            Text('PLAYERS', style: AppTextStyles.overline),
            const SizedBox(height: 10),
            Row(
              children: [
                for (var count = 2; count <= 6; count++) ...[
                  Expanded(child: _PlayerCountOption(
                    count: count,
                    selected: _maxPlayers == count,
                    onTap: () => setState(() => _maxPlayers = count),
                  )),
                  if (count != 6) const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 26),
            Text('DECK SIZE', style: AppTextStyles.overline),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _deckSizeOptions.map((size) {
                final selected = _deckSize == size;
                return _DeckSizeChip(
                  label: size == null ? 'ALL CARDS' : '$size CARDS',
                  selected: selected,
                  onTap: () => setState(() => _deckSize = size),
                );
              }).toList(),
            ),
            const SizedBox(height: 22),
            GlassPanel(
              borderRadius: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Potential Reward Pool', style: AppTextStyles.body),
                  Row(
                    children: [
                      const Icon(Icons.monetization_on, size: 18, color: AppColors.gold),
                      const SizedBox(width: 6),
                      Text('$potentialPool', style: AppTextStyles.title.copyWith(color: AppColors.gold)),
                    ],
                  ),
                ],
              ),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 16),
              Text(_errorText!, style: TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 24),
            PremiumButton(label: 'Create Room', onPressed: _submit, isLoading: _isSubmitting),
          ],
        ),
      ),
    );
  }
}

class _CardSetTile extends StatelessWidget {
  const _CardSetTile({required this.cardSet, required this.selected, required this.onTap});
  final CardSet cardSet;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 92,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: selected ? AppColors.goldGradient : null,
          color: selected ? null : AppColors.glassFill,
          border: Border.all(color: selected ? AppColors.gold : AppColors.glassBorder, width: selected ? 0 : 1),
          boxShadow: selected
              ? [BoxShadow(color: AppColors.gold.withValues(alpha: 0.4), blurRadius: 14, spreadRadius: 1)]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.style, size: 22, color: selected ? AppColors.navyDark : AppColors.skyBlue),
            const SizedBox(height: 6),
            Text(
              cardSet.code,
              style: AppTextStyles.title.copyWith(color: selected ? AppColors.navyDark : AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryChip extends StatelessWidget {
  const _EntryChip({required this.amount, required this.selected, required this.onTap});
  final int amount;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: selected ? AppColors.goldGradient : null,
          color: selected ? null : AppColors.glassFill,
          border: Border.all(color: selected ? AppColors.gold : AppColors.glassBorder, width: selected ? 0 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (amount > 0) ...[
              Icon(Icons.monetization_on, size: 15, color: selected ? AppColors.navyDark : AppColors.gold),
              const SizedBox(width: 5),
            ],
            Text(
              amount == 0 ? 'FREE' : '$amount',
              style: AppTextStyles.title.copyWith(
                fontSize: 14,
                color: selected ? AppColors.navyDark : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeckSizeChip extends StatelessWidget {
  const _DeckSizeChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: selected ? AppColors.goldGradient : null,
          color: selected ? null : AppColors.glassFill,
          border: Border.all(color: selected ? AppColors.gold : AppColors.glassBorder, width: selected ? 0 : 1),
        ),
        child: Text(
          label,
          style: AppTextStyles.title.copyWith(
            fontSize: 13,
            color: selected ? AppColors.navyDark : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _PlayerCountOption extends StatelessWidget {
  const _PlayerCountOption({required this.count, required this.selected, required this.onTap});
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: selected ? AppColors.goldGradient : null,
          color: selected ? null : AppColors.glassFill,
          border: Border.all(color: selected ? AppColors.gold : AppColors.glassBorder, width: selected ? 0 : 1),
        ),
        child: Text(
          '$count',
          style: AppTextStyles.title.copyWith(color: selected ? AppColors.navyDark : AppColors.textPrimary),
        ),
      ),
    );
  }
}
