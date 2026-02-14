import 'package:flutter/material.dart';
import '../models/monitor_models.dart';
import '../models/monitor_room_statistics.dart';
import '../services/http_service.dart';
import '../services/database_service.dart';
import '../design/app_colors.dart';
import '../design/app_text_styles.dart';
import '../widgets/common/photo_widget.dart';

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

  String _formatDateTime(String dateTimeString, String format) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      final day = dateTime.day.toString().padLeft(2, '0');
      final month = dateTime.month.toString().padLeft(2, '0');
      final year = dateTime.year.toString();
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      
      return '$day.$month.$year $hour:$minute';
    } catch (e) {
      return dateTimeString; // Return original string if parsing fails
    }
  }

  Future<void> _loadMonitors() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load REGISTERED monitors from local database by room ID
      final allRegistered = await DatabaseService.getRegisteredMonitors();
      final monitors = allRegistered
          .where((m) => m.roomId == widget.roomStats.roomId)
          .toList();

      setState(() {
        _monitors = monitors;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Xəta: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildStatisticsCard(),
                const SizedBox(height: 20),
                _buildMonitorsList(),
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

  Widget _buildStatisticsCard() {
    final stats = widget.roomStats;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMonitorsList() {
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
                const Icon(
                  Icons.list,
                  color: Color(0xFF059669),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'İmtahan rəhbərləri siyahısı',
                  style: AppTextStyles.heading4.copyWith(
                    color: const Color(0xFF059669),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _monitors!.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final monitor = _monitors![index];
              return _buildMonitorItem(monitor);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMonitorItem(Monitor monitor) {
    final isRegistered = monitor.registerDate.isNotEmpty;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            border: Border.all(
              color: isRegistered ? Colors.green : Colors.grey,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(25),
          ),
          child: PhotoWidget.monitor(
            photoData: monitor.image,
            width: 50,
            height: 50,
          ),
        ),
      ),
      title: Text(
        '${monitor.firstName} ${monitor.lastName}',
        style: AppTextStyles.body1.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'İş nömrəsi: ${monitor.workNumber}',
            style: AppTextStyles.caption,
          ),
          if (isRegistered)
            Text(
              'Qeydiyyat: ${_formatDateTime(monitor.registerDate, 'dd.MM.yyyy HH:mm')}',
              style: AppTextStyles.caption.copyWith(
                color: Colors.green,
              ),
            ),
        ],
      ),
      trailing: Icon(
        isRegistered ? Icons.check_circle : Icons.pending,
        color: isRegistered ? Colors.green : Colors.orange,
      ),
    );
  }
}
