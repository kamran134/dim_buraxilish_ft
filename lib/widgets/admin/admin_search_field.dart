import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/app_theme.dart';

/// Search field for the gradient background: white, radius 16, search icon,
/// clear button. [onChanged] is debounced by [debounce] (400 ms); pressing
/// "search" on the keyboard fires [onChanged] immediately.
class AdminSearchField extends StatefulWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  final Duration debounce;
  final TextInputType? keyboardType;
  final bool autofocus;

  const AdminSearchField({
    super.key,
    this.hint = 'Axtar',
    required this.onChanged,
    this.controller,
    this.debounce = const Duration(milliseconds: 400),
    this.keyboardType,
    this.autofocus = false,
  });

  @override
  State<AdminSearchField> createState() => _AdminSearchFieldState();
}

class _AdminSearchFieldState extends State<AdminSearchField> {
  late final TextEditingController _controller;
  late final bool _ownsController;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? TextEditingController();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.removeListener(_onTextChanged);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  String _lastText = '';

  void _onTextChanged() {
    // The listener also fires on selection changes; only react to text.
    if (_controller.text == _lastText) {
      setState(() {});
      return;
    }
    _lastText = _controller.text;
    setState(() {});
    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.debounce, () {
      if (mounted) widget.onChanged(_controller.text);
    });
  }

  void _submit(String value) {
    _debounceTimer?.cancel();
    widget.onChanged(value);
  }

  void _clear() {
    _debounceTimer?.cancel();
    _controller.clear();
    _lastText = '';
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      autofocus: widget.autofocus,
      keyboardType: widget.keyboardType,
      textInputAction: TextInputAction.search,
      onSubmitted: _submit,
      style: AppTextStyles.bodyMedium,
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textHint,
        ),
        filled: true,
        fillColor: Colors.white,
        constraints: const BoxConstraints(minHeight: AppSpacing.buttonHeight),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + AppSpacing.xs,
        ),
        prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Təmizlə',
                onPressed: _clear,
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
              ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLG),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
