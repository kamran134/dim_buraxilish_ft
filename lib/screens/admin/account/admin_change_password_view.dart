import 'package:flutter/material.dart';

import '../../../design/app_theme.dart';
import '../../../widgets/admin/admin_widgets.dart';

/// Şifrəni dəyiş: current password, new password (at least 3 characters, as
/// in the web admin) and its repetition. [onSubmit] resolves to whether the
/// password was changed; the fields are cleared then.
class AdminChangePasswordView extends StatefulWidget {
  static const int minLength = 3;

  /// Account the password belongs to (read-only; the API wants it in the
  /// request).
  final String userName;
  final bool submitting;

  /// Server message of the last failed attempt.
  final String? error;

  final Future<bool> Function(String currentPassword, String newPassword)
      onSubmit;

  const AdminChangePasswordView({
    super.key,
    required this.userName,
    this.submitting = false,
    this.error,
    required this.onSubmit,
  });

  @override
  State<AdminChangePasswordView> createState() =>
      _AdminChangePasswordViewState();
}

class _AdminChangePasswordViewState extends State<AdminChangePasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.submitting || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final changed = await widget.onSubmit(_current.text, _new.text);
    if (!mounted || !changed) return;
    _current.clear();
    _new.clear();
    _confirm.clear();
    _formKey.currentState?.reset();
  }

  String? _required(String? value, String label) =>
      (value == null || value.isEmpty) ? '$label tələb olunur' : null;

  InputDecoration _decoration({
    required String label,
    required bool visible,
    required VoidCallback onToggle,
  }) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      suffixIcon: IconButton(
        tooltip: visible ? 'Gizlət' : 'Göstər',
        onPressed: onToggle,
        icon: Icon(visible ? Icons.visibility_off : Icons.visibility),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminPage.list(
      title: 'Şifrəni dəyiş',
      children: [
        AdminCard(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.person, color: AdminStyle.accent(context)),
                    AppSpacing.horizontalGapSM,
                    Expanded(
                      child: Text(
                        widget.userName.isEmpty
                            ? 'İstifadəçi'
                            : widget.userName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AdminStyle.textPrimary(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                AppSpacing.verticalGapMD,
                TextFormField(
                  controller: _current,
                  obscureText: !_showCurrent,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.next,
                  decoration: _decoration(
                    label: 'Cari parol',
                    visible: _showCurrent,
                    onToggle: () => setState(() => _showCurrent = !_showCurrent),
                  ),
                  validator: (v) => _required(v, 'Cari parol'),
                ),
                AppSpacing.verticalGapMD,
                TextFormField(
                  controller: _new,
                  obscureText: !_showNew,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.next,
                  decoration: _decoration(
                    label: 'Yeni parol',
                    visible: _showNew,
                    onToggle: () => setState(() => _showNew = !_showNew),
                  ),
                  validator: (v) {
                    final missing = _required(v, 'Yeni parol');
                    if (missing != null) return missing;
                    if (v!.length < AdminChangePasswordView.minLength) {
                      return 'Parol ən azı ${AdminChangePasswordView.minLength} '
                          'simvol olmalıdır';
                    }
                    return null;
                  },
                ),
                AppSpacing.verticalGapMD,
                TextFormField(
                  controller: _confirm,
                  obscureText: !_showConfirm,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: _decoration(
                    label: 'Parol təkrarı',
                    visible: _showConfirm,
                    onToggle: () => setState(() => _showConfirm = !_showConfirm),
                  ),
                  validator: (v) {
                    final missing = _required(v, 'Parol təkrarı');
                    if (missing != null) return missing;
                    return v != _new.text ? 'Parollar uyğun gəlmir' : null;
                  },
                ),
                if (widget.error != null) ...[
                  AppSpacing.verticalGapMD,
                  Text(
                    widget.error!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ],
                AppSpacing.verticalGapLG,
                AdminActionButton(
                  label: 'Şifrəni dəyiş',
                  icon: Icons.key,
                  style: AdminActionStyle.filled,
                  loading: widget.submitting,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
