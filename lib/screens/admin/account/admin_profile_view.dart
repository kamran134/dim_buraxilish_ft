import 'package:flutter/material.dart';

import '../../../design/app_theme.dart';
import '../../../models/admin_models.dart';
import '../../../utils/date_formatter.dart';
import '../../../widgets/admin/admin_widgets.dart';

/// What the profile shows besides the server data (all from the local
/// session).
class AdminSessionInfo {
  final String? examLabel;
  final DateTime? loginTime;
  final DateTime? tokenExpiration;

  const AdminSessionInfo({this.examLabel, this.loginTime, this.tokenExpiration});
}

/// "3 saat 5 dəqiqə" / "12 dəqiqə".
String formatSessionDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  return hours > 0 ? '$hours saat $minutes dəqiqə' : '$minutes dəqiqə';
}

/// Profil: who is signed in (`auth/me`) and the state of the session. When
/// the server cannot be reached [user] is built from the token by the loader
/// and [error] explains the stale data.
class AdminProfileView extends StatelessWidget {
  final CurrentUser? user;
  final String? error;
  final AdminSessionInfo session;
  final DateTime Function() clock;
  final Future<void> Function() onRefresh;
  final VoidCallback onChangePassword;

  const AdminProfileView({
    super.key,
    this.user,
    this.error,
    this.session = const AdminSessionInfo(),
    this.clock = DateTime.now,
    required this.onRefresh,
    required this.onChangePassword,
  });

  static const String _title = 'Profil';

  @override
  Widget build(BuildContext context) {
    final current = user;
    if (current == null) {
      return AdminPage(
        title: _title,
        body: error != null
            ? AdminErrorState(message: error!, onRetry: onRefresh)
            : const AdminLoading(),
      );
    }

    final loginTime = session.loginTime;
    final expiration = session.tokenExpiration;
    return AdminPage.list(
      title: _title,
      onRefresh: onRefresh,
      children: [
        if (error != null)
          AdminCard(
            child: Row(
              children: [
                const Icon(Icons.cloud_off, color: AppColors.warning),
                AppSpacing.horizontalGapSM,
                Expanded(
                  child: Text(
                    error!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AdminStyle.textPrimary(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        AdminGlassCard(
          child: Row(
            children: [
              const CircleAvatar(
                radius: AppSpacing.avatarMD,
                backgroundColor: Colors.white24,
                child: Icon(Icons.person, color: Colors.white, size: 32),
              ),
              AppSpacing.horizontalGapMD,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      current.userName.isEmpty ? 'İstifadəçi' : current.userName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.h5.copyWith(color: Colors.white),
                    ),
                    Text(
                      current.roleLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        AdminCard(
          title: 'Hesab',
          child: AdminKeyValueList(
            items: [
              AdminKeyValue('İstifadəçi adı', current.userName),
              AdminKeyValue('Rol', current.roleLabel),
              if ((current.buildingCode ?? '').isNotEmpty &&
                  current.buildingCode != '0')
                AdminKeyValue('Bina kodu', current.buildingCode!),
              if ((current.buildingName ?? '').isNotEmpty)
                AdminKeyValue('Bina', current.buildingName!),
            ],
          ),
        ),
        AdminCard(
          title: 'Sessiya',
          child: AdminKeyValueList(
            items: [
              AdminKeyValue('Cari imtahan', session.examLabel ?? ''),
              AdminKeyValue(
                'Giriş vaxtı',
                loginTime == null
                    ? ''
                    : DateFormatter.formatDateTimeToAz(loginTime),
              ),
              AdminKeyValue(
                'Sessiya müddəti',
                loginTime == null
                    ? ''
                    : formatSessionDuration(clock().difference(loginTime)),
              ),
              AdminKeyValue(
                'Token bitmə vaxtı',
                expiration == null
                    ? ''
                    : DateFormatter.formatDateTimeToAz(expiration),
              ),
            ],
          ),
        ),
        AdminActionButton(
          label: 'Şifrəni dəyiş',
          icon: Icons.key,
          onPressed: onChangePassword,
        ),
      ],
    );
  }
}
