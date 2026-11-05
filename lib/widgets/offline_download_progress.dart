import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/offline_database_provider.dart';

/// Progress of [OfflineDatabaseProvider.downloadOfflineDatabase], shared by
/// every screen that runs the download: an indeterminate bar while the lists
/// load, then a determinate one with `done / total · percent` while the
/// photos come in.
///
/// [color] is used for the text and the bar (its track is a faded copy), so
/// pass white on a dark card and the primary color on a light one.
class OfflineDownloadProgress extends StatelessWidget {
  final Color color;

  const OfflineDownloadProgress({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineDatabaseProvider>(
      builder: (context, provider, _) {
        final photos = provider.downloadPhase == OfflineDownloadPhase.photos;
        final total = provider.photosTotal ?? 0;
        final done =
            (provider.photosDone ?? 0).clamp(0, total > 0 ? total : 0).toInt();
        final fraction = total > 0 ? done / total : 0.0;
        final percent = (fraction * 100).floor();

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              photos ? 'Şəkillər yüklənir' : 'Məlumatlar yüklənir',
              textAlign: TextAlign.center,
              style: _style(color, 17, FontWeight.w700),
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                // null value = indeterminate.
                value: photos ? fraction : null,
                minHeight: 8,
                color: color,
                backgroundColor: color.withValues(alpha: 0.2),
              ),
            ),
            if (photos) ...[
              const SizedBox(height: 10),
              Text(
                '$done / $total · $percent%',
                textAlign: TextAlign.center,
                style: _style(color.withValues(alpha: 0.85), 14),
              ),
            ],
            if (provider.photosRetrying) ...[
              const SizedBox(height: 8),
              Text(
                'Bağlantı bərpa olunur...',
                textAlign: TextAlign.center,
                style: _style(color.withValues(alpha: 0.85), 13),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Tətbiqi bağlamayın',
              textAlign: TextAlign.center,
              style: _style(color.withValues(alpha: 0.6), 12),
            ),
          ],
        );
      },
    );
  }

  static TextStyle _style(Color color, double size,
      [FontWeight weight = FontWeight.w400]) {
    return TextStyle(
      color: color,
      fontSize: size,
      fontWeight: weight,
      decoration: TextDecoration.none,
    );
  }
}
