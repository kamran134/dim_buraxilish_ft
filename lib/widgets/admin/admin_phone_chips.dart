import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../design/app_theme.dart';

/// Splits a stored phone field ("a, b") into trimmed non-empty numbers.
List<String> splitAdminPhones(String? raw) => (raw ?? '')
    .split(',')
    .map((phone) => phone.trim())
    .where((phone) => phone.isNotEmpty)
    .toList();

/// Opens the dialer with [phone]; silently does nothing when it cannot.
Future<void> callAdminPhone(String phone) async {
  final cleaned = phone.trim();
  if (cleaned.isEmpty) return;
  final uri = Uri(scheme: 'tel', path: cleaned);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// Tappable phone numbers (one pill each) that wrap onto several lines.
class AdminPhoneChips extends StatelessWidget {
  final List<String> phones;
  final ValueChanged<String> onCall;

  const AdminPhoneChips({
    super.key,
    required this.phones,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final phone in phones)
          Material(
            color: AppColors.info,
            borderRadius: BorderRadius.circular(AppSpacing.borderRadiusXL),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppSpacing.borderRadiusXL),
              onTap: () => onCall(phone),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.call, size: 16, color: Colors.white),
                      AppSpacing.horizontalGapXS,
                      Flexible(
                        child: Text(
                          phone,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
