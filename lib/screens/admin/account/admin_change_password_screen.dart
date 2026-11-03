import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/auth_models.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/http_service.dart';
import '../../../utils/role_helper.dart';
import 'admin_change_password_view.dart';

/// Loader of Şifrəni dəyiş: `password/changepassword` through the existing
/// [HttpService.changePassword].
class AdminChangePasswordScreen extends StatefulWidget {
  const AdminChangePasswordScreen({super.key});

  @override
  State<AdminChangePasswordScreen> createState() =>
      _AdminChangePasswordScreenState();
}

class _AdminChangePasswordScreenState extends State<AdminChangePasswordScreen> {
  final HttpService _http = HttpService();

  bool _submitting = false;
  String? _error;

  Future<bool> _submit(String currentPassword, String newPassword) async {
    final userName = _userName();
    setState(() {
      _submitting = true;
      _error = null;
    });

    ResponseModel result;
    try {
      result = await _http.changePassword(ChangePasswordModel(
        userName: userName,
        currentPassword: currentPassword,
        newPassword: newPassword,
      ));
    } catch (_) {
      result = ResponseModel(
        success: false,
        message: 'Parol dəyişdirilərkən xəta baş verdi',
      );
    }
    if (!mounted) return false;

    setState(() {
      _submitting = false;
      if (!result.success) {
        _error = result.message.isEmpty
            ? 'Parol dəyişdirilərkən xəta baş verdi'
            : result.message;
      }
    });
    if (result.success) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Parol uğurla dəyişdirildi!')),
        );
    }
    return result.success;
  }

  String _userName() => RoleHelper.getUserNameFromToken(
        context.read<AuthProvider>().accessToken?.token,
      ) ??
      '';

  @override
  Widget build(BuildContext context) {
    return AdminChangePasswordView(
      userName: _userName(),
      submitting: _submitting,
      error: _error,
      onSubmit: _submit,
    );
  }
}
