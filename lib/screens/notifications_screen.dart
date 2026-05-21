import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notification_message.dart';
import '../providers/notifications_provider.dart';
import '../providers/font_provider.dart';
import '../design/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<NotificationsProvider>();
      await provider.load();
      await provider.fetchPending();
      await provider.markAllRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.lightBackground,
      appBar: AppBar(
        title: Consumer<FontProvider>(
          builder: (context, fp, _) => Text(
            'Bildirişlər',
            style: fp.titleLarge.copyWith(color: Colors.white),
          ),
        ),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          Consumer<NotificationsProvider>(
            builder: (context, provider, _) {
              if (provider.loading) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                );
              }
              return IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () async {
                  await provider.fetchPending();
                  await provider.load();
                },
              );
            },
          ),
        ],
      ),
      body: Consumer<NotificationsProvider>(
        builder: (context, provider, _) {
          if (provider.loading && provider.messages.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.messages.isEmpty) {
            return _EmptyState(isDark: isDark);
          }

          final items = _buildListItems(provider.messages);

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              if (item is _DateHeader) {
                return _DateSeparator(label: item.label, isDark: isDark);
              }
              final msg = item as NotificationMessage;
              return _NotificationCard(
                message: msg,
                isDark: isDark,
                onAcknowledge: () async {
                  await provider.acknowledge(msg.messageId);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Mesaj təsdiqləndi'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  List<Object> _buildListItems(List<NotificationMessage> messages) {
    final items = <Object>[];
    String? lastDateKey;

    for (final msg in messages) {
      final dateKey = _dateKey(msg.receivedAt);
      if (dateKey != lastDateKey) {
        items.add(_DateHeader(label: _formatDateHeader(msg.receivedAt)));
        lastDateKey = dateKey;
      }
      items.add(msg);
    }
    return items;
  }

  String _dateKey(String isoDate) {
    final dt = DateTime.tryParse(isoDate);
    if (dt == null) return isoDate;
    return '${dt.year}-${dt.month}-${dt.day}';
  }

  String _formatDateHeader(String isoDate) {
    final dt = DateTime.tryParse(isoDate)?.toLocal();
    if (dt == null) return isoDate;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(msgDay).inDays;

    if (diff == 0) return 'Bu gün';
    if (diff == 1) return 'Dünən';

    const months = [
      '', 'Yanvar', 'Fevral', 'Mart', 'Aprel', 'May', 'İyun',
      'İyul', 'Avqust', 'Sentyabr', 'Oktyabr', 'Noyabr', 'Dekabr',
    ];
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  }
}

class _DateHeader {
  final String label;
  _DateHeader({required this.label});
}

// ─── Date separator ──────────────────────────────────────────────────────────

class _DateSeparator extends StatelessWidget {
  final String label;
  final bool isDark;

  const _DateSeparator({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: isDark ? Colors.white24 : Colors.grey.shade300,
              thickness: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF334155)
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.grey.shade600,
                ),
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: isDark ? Colors.white24 : Colors.grey.shade300,
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Notification card ────────────────────────────────────────────────────────

class _NotificationCard extends StatelessWidget {
  final NotificationMessage message;
  final bool isDark;
  final VoidCallback onAcknowledge;

  const _NotificationCard({
    required this.message,
    required this.isDark,
    required this.onAcknowledge,
  });

  static const _importanceColors = [
    Color(0xFF1565C0), // info — blue
    Color(0xFFF57C00), // warning — orange
    Color(0xFFD32F2F), // critical — red
  ];

  static const _importanceBgLight = [
    Color(0xFFE3F2FD),
    Color(0xFFFFF3E0),
    Color(0xFFFFEBEE),
  ];

  static const _importanceBgDark = [
    Color(0xFF1A2A3F),
    Color(0xFF2D2010),
    Color(0xFF2D1010),
  ];

  static const _importanceBadges = ['MƏLUMAT', 'XƏBƏRDARLIQ', 'TƏCİLİ ELAN'];
  static const _importanceIcons = [
    Icons.info_outline,
    Icons.warning_amber_outlined,
    Icons.campaign_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final idx = message.importance.clamp(0, 2);
    final accentColor = _importanceColors[idx];
    final bgColor =
        isDark ? _importanceBgDark[idx] : _importanceBgLight[idx];
    final timeStr = _formatTime(message.receivedAt);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.4),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.grey.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header strip
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Icon(_importanceIcons[idx],
                      size: 18, color: accentColor),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _importanceBadges[idx],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            // Body
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: Text(
                message.title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            if (message.body.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 2, 14, 0),
                child: Text(
                  message.body,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black54,
                    height: 1.4,
                  ),
                ),
              ),

            // Acknowledge button OR read timestamp
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
              child: Align(
                alignment: Alignment.centerRight,
                child: message.isRead
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.done_all,
                              size: 14,
                              color: isDark
                                  ? Colors.white38
                                  : Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text(
                            'Oxundu: ${_formatTime(message.readAt ?? message.receivedAt)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.white38
                                  : Colors.grey.shade400,
                            ),
                          ),
                        ],
                      )
                    : TextButton.icon(
                        onPressed: onAcknowledge,
                        icon: Icon(Icons.check_circle_outline,
                            size: 16, color: accentColor),
                        label: Text(
                          'Təsdiqlə',
                          style: TextStyle(
                            fontSize: 13,
                            color: accentColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String isoDate) {
    final dt = DateTime.tryParse(isoDate)?.toLocal();
    if (dt == null) return '';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isDark;
  const _EmptyState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none_outlined,
            size: 72,
            color: isDark ? Colors.white24 : Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'Bildiriş yoxdur',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white38 : Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ekstremal mesajlar burada görünəcək',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white24 : Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }
}
