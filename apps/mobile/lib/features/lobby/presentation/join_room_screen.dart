import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/premium_button.dart';
import '../data/rooms_repository.dart';

const _codeLength = 6;

class JoinRoomScreen extends ConsumerStatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  ConsumerState<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends ConsumerState<JoinRoomScreen> {
  final _codeController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _codeController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length < _codeLength) {
      setState(() => _errorText = 'Enter the full $_codeLength-character code');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      await ref.read(roomsRepositoryProvider).join(code);
      if (mounted) context.go('/lobby/$code');
    } catch (error) {
      if (mounted) setState(() => _errorText = describeApiError(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = _codeController.text.toUpperCase();

    return Scaffold(
      appBar: AppBar(title: Text('Join Room', style: AppTextStyles.title)),
      body: AppBackground(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('ENTER ROOM CODE', textAlign: TextAlign.center, style: AppTextStyles.overline),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => _focusNode.requestFocus(),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < _codeLength; i++) ...[
                            _CodeBox(
                              char: i < text.length ? text[i] : '',
                              active: i == text.length && _focusNode.hasFocus,
                            ),
                            if (i != _codeLength - 1) const SizedBox(width: 8),
                          ],
                        ],
                      ),
                      Opacity(
                        opacity: 0,
                        child: TextField(
                          controller: _codeController,
                          focusNode: _focusNode,
                          autofocus: true,
                          maxLength: _codeLength,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]'))],
                          decoration: const InputDecoration(counterText: ''),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 20),
                  Text(_errorText!, textAlign: TextAlign.center, style: TextStyle(color: AppColors.danger)),
                ],
                const SizedBox(height: 28),
                PremiumButton(label: 'Join', onPressed: _submit, isLoading: _isSubmitting),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CodeBox extends StatelessWidget {
  const _CodeBox({required this.char, required this.active});
  final String char;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final filled = char.isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 42,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: filled ? AppColors.glassFill : Colors.transparent,
        border: Border.all(
          color: active ? AppColors.gold : (filled ? AppColors.glassBorder : AppColors.glassBorder),
          width: active ? 2 : 1,
        ),
        boxShadow: active ? [BoxShadow(color: AppColors.gold.withValues(alpha: 0.35), blurRadius: 12)] : null,
      ),
      child: Text(char, style: AppTextStyles.headline.copyWith(fontSize: 24)),
    );
  }
}
