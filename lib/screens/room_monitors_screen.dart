import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/monitor_models.dart';
import '../models/monitor_room_statistics.dart';
import '../services/database_service.dart';
import '../services/http_service.dart';
import '../utils/date_formatter.dart';
import '../design/app_colors.dart';
import '../design/app_text_styles.dart';

class RoomMonitorsScreen extends StatefulWidget {
  final MonitorRoomStatistics roomStats;

  const RoomMonitorsScreen({
    Key? key,
    required this.roomStats,
  }) : super(key: key);

  @override
  State<RoomMonitorsScreen> createState() => _RoomMonitorsScreenState();
}

class _RoomMonitorsScreenState extends State<RoomMonitorsScreen> {
  List<Monitor>? _monitors;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMonitors();
  }

  Future<void> _loadMonitors() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final httpService = HttpService();
      final examDetails = await httpService.getExamDetailsFromStorage();
      final imtTarix = examDetails?.imtTarix ?? '';

      List<Monitor> allMonitors = [];

      // Try API: GetByRoomIdAndExamDate — no building code needed, same format as supervisors/scanMonitor
      if (imtTarix.isNotEmpty) {
        try {
          allMonitors = await httpService.getMonitorsByRoomId(
            roomId: widget.roomStats.roomId,
            examDate: imtTarix,
          );
        } catch (_) {
          // API unavailable, will try offline below
        }
      }

      // Fallback: offline all_monitors table (cached on admin login)
      if (allMonitors.isEmpty) {
        allMonitors = await DatabaseService.getAllMonitorsByRoomOffline(
          widget.roomStats.roomId,
        );
      }

      if (allMonitors.isNotEmpty) {
        // Overlay registration status from local registered_monitors
        final registered = await DatabaseService.getRegisteredMonitorsByRoom(
          widget.roomStats.roomId,
          examDate: widget.roomStats.examDate,
        );
        final registeredMap = {for (final m in registered) m.workNumber: m};

        final merged = allMonitors.map((m) {
          final reg = registeredMap[m.workNumber];
          if (reg == null) return m; // unregistered: use API data as-is
          // registered: keep all API fields (incl. image), just override registerDate
          return Monitor(
            workNumber: m.workNumber,
            firstName: m.firstName,
            lastName: m.lastName,
            middleName: m.middleName,
            idCardPin: m.idCardPin,
            buildingCode: m.buildingCode,
            buildingName: m.buildingName,
            roomId: m.roomId,
            roomName: m.roomName,
            examDate: m.examDate,
            registerDate: reg.registerDate,
            image: m.image.isNotEmpty ? m.image : reg.image,
            phone: m.phone,
            online: m.online,
          );
        }).toList()
          ..sort((a, b) {
            if (a.isRegistered && !b.isRegistered) return -1;
            if (!a.isRegistered && b.isRegistered) return 1;
            return 0;
          });

        setState(() {
          _monitors = merged;
          _isLoading = false;
        });
      } else {
        // Last resort: only scanned-in monitors (monitor device, offline)
        final monitors = await DatabaseService.getRegisteredMonitorsByRoom(
          widget.roomStats.roomId,
          examDate: widget.roomStats.examDate,
        );
        setState(() {
          _monitors = monitors;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Xəta: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.lightBackground,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildStatisticsCard(isDark),
                const SizedBox(height: 20),
                _buildMonitorsList(isDark),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF059669), // emerald-600
              Color(0xFF047857), // emerald-700
            ],
          ),
        ),
        child: FlexibleSpaceBar(
          titlePadding: const EdgeInsets.only(left: 72, bottom: 16),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.roomStats.roomName,
                style: AppTextStyles.h2.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'İmtahan rəhbərləri',
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildStatisticsCard(bool isDark) {
    final stats = widget.roomStats;
    final cardBg = isDark ? AppColors.surfaceDark : Colors.white;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.room,
                color: Color(0xFF059669),
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Otaq statistikası',
                style: AppTextStyles.heading3.copyWith(
                  color: const Color(0xFF059669),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Ümumi',
                  stats.allPersonCount.toString(),
                  Colors.blue,
                  Icons.people,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  'Qeydiyyatdan keçən',
                  stats.regPersonCount.toString(),
                  Colors.green,
                  Icons.check_circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Qeydiyyatdan keçməyən',
                  stats.unregisteredCount.toString(),
                  Colors.red,
                  Icons.cancel,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  'Qeydiyyat faizi',
                  '${stats.registrationPercentage.toStringAsFixed(1)}%',
                  const Color(0xFF059669),
                  Icons.percent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, Color color, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? Colors.white70 : Colors.black54;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.h2.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: labelColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMonitorsList(bool isDark) {
    final cardBg = isDark ? AppColors.surfaceDark : Colors.white;
    final headerColor = isDark ? Colors.white : const Color(0xFF059669);
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(
            color: Color(0xFF059669),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: AppTextStyles.body1.copyWith(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadMonitors,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                ),
                child: const Text('Yenidən yüklə'),
              ),
            ],
          ),
        ),
      );
    }

    if (_monitors == null || _monitors!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              const Icon(
                Icons.inbox,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                'Məlumat yoxdur',
                style: AppTextStyles.body1.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(
                  Icons.list,
                  color: headerColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'İmtahan rəhbərləri siyahısı',
                  style: AppTextStyles.heading4.copyWith(
                    color: headerColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? Colors.white12 : Colors.black12),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _monitors!.length,
              itemBuilder: (context, index) {
                final monitor = _monitors![index];
                return _buildMonitorItem(monitor, isDark);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonitorItem(Monitor monitor, bool isDark) {
    final isRegistered = monitor.registerDate.isNotEmpty;
    final borderColor =
        isRegistered ? const Color(0xFF059669) : Colors.red.shade400;
    final bgColor = isDark
        ? (isRegistered
            ? Colors.green.withOpacity(0.15)
            : Colors.red.withOpacity(0.15))
        : (isRegistered
            ? Colors.green.withOpacity(0.10)
            : Colors.red.withOpacity(0.10));
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Avatar
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: borderColor.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: monitor.image.isNotEmpty && monitor.image != 'null'
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(25),
                              child: Image.memory(
                                base64Decode(monitor.image),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.person,
                                        color: Colors.white, size: 24),
                              ),
                            )
                          : const Icon(Icons.person,
                              color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    // Name
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${monitor.lastName} ${monitor.firstName}',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (monitor.middleName.isNotEmpty)
                            Text(
                              monitor.middleName,
                              style:
                                  TextStyle(color: subTextColor, fontSize: 14),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 28),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInfoRow(Icons.badge, 'İş nömrəsi',
                    monitor.workNumber.toString(), textColor, subTextColor),
                if (isRegistered)
                  _buildInfoRow(
                      Icons.access_time,
                      'Qeydiyyat vaxtı',
                      DateFormatter.formatISOToAz(monitor.registerDate),
                      textColor,
                      subTextColor),
                if (monitor.idCardPin.isNotEmpty)
                  _buildInfoRow(Icons.credit_card, 'FİN', monitor.idCardPin,
                      textColor, subTextColor),
                if (monitor.roomName.isNotEmpty)
                  _buildInfoRow(Icons.meeting_room, 'Otaq', monitor.roomName,
                      textColor, subTextColor),
                if (monitor.phone != null && monitor.phone!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _buildPhoneChips(monitor.phone!),
                ],
              ],
            ),
          ),
          // Corner status badge
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: borderColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isRegistered ? Icons.check : Icons.close,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value,
      Color textColor, Color subTextColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: subTextColor),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(color: subTextColor, fontSize: 14),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneChips(String phones) {
    final numbers = phones
        .split(RegExp(r'[,،]\s*'))
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty)
        .toList();
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: numbers.map(_buildPhoneChip).toList(),
    );
  }

  Widget _buildPhoneChip(String phone) {
    return InkWell(
      onTap: () => _callPhone(phone),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF0EA5E9).withOpacity(0.1),
          border: Border.all(color: const Color(0xFF0EA5E9)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.phone, size: 13, color: Color(0xFF0EA5E9)),
            const SizedBox(width: 5),
            Text(
              phone,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF0EA5E9),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _callPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.trim());
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
