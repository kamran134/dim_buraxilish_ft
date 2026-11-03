import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/admin_models.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/admin_service.dart';
import '../../../utils/role_helper.dart';
import 'admin_change_password_screen.dart';
import 'admin_profile_view.dart';

/// Loader of Profil: `auth/me`, falling back to what the token knows when
/// the server cannot be reached.
class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  final AdminService _service = AdminService();

  CurrentUser? _user;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await _service.getCurrentUser();
    if (!mounted) return;
    setState(() {
      final data = result.data;
      if (result.success && data != null) {
        _user = data;
        _error = null;
      } else {
        _error = result.message;
        _user ??= _userFromToken();
      }
    });
  }

  /// Offline fallback: the name, role and building the JWT carries.
  CurrentUser _userFromToken() {
    final auth = context.read<AuthProvider>();
    final token = auth.accessToken?.token;
    return CurrentUser(
      userName: RoleHelper.getUserNameFromToken(token) ?? '',
      role: auth.currentUserRole ?? RoleHelper.getRoleFromToken(token) ?? '',
      buildingCode: RoleHelper.getBinaFromToken(token),
      buildingName: RoleHelper.getAdBinaFromToken(token),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final token = auth.accessToken;
    return AdminProfileView(
      user: _user,
      error: _error,
      session: AdminSessionInfo(
        examLabel: auth.activeExamHeaderLabel,
        loginTime: RoleHelper.getIssuedAtFromToken(token?.token),
        tokenExpiration: DateTime.tryParse(token?.expiration ?? ''),
      ),
      onRefresh: _load,
      onChangePassword: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AdminChangePasswordScreen()),
      ),
    );
  }
}
