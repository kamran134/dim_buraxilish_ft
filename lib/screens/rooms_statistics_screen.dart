import 'package:flutter/material.dart';
import '../models/monitor_room_statistics.dart';
import '../services/statistics_service.dart';
import '../design/app_colors.dart';
import '../design/app_text_styles.dart';
import '../widgets/admin_drawer.dart';
import 'room_monitors_screen.dart';

class RoomsStatisticsScreen extends StatefulWidget {
  final String? initialExamDate;

  const RoomsStatisticsScreen({Key? key, this.initialExamDate})
      : super(key: key);

  @override
  State<RoomsStatisticsScreen> createState() => _RoomsStatisticsScreenState();
}

class _RoomsStatisticsScreenState extends State<RoomsStatisticsScreen> {
  final StatisticsService _statisticsService = StatisticsService();
  List<MonitorRoomStatistics> _roomStatistics = [];
  List<String> _examDates = [];
  String? _selectedExamDate;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedExamDate = widget.initialExamDate;
    _loadExamDates();
  }

  Future<void> _loadExamDates() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _statisticsService.getAllExamDates();
      if (result.success && result.data != null) {
        setState(() {
          _examDates = result.data!;
          if (_selectedExamDate == null && _examDates.isNotEmpty) {
            _selectedExamDate = _examDates.first;
          }
        });
        if (_selectedExamDate != null) {
          await _loadRoomStatistics(_selectedExamDate!);
        }
      } else {
        setState(() {
          _errorMessage = result.message;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Tarixlər yüklənmədi: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRoomStatistics(String examDate) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _statisticsService.getAllRoomStatistics(examDate);
      if (result.success && result.data != null) {
        setState(() {
          _roomStatistics = result.data!;
        });
      } else {
        setState(() {
          _errorMessage = result.message;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Statistika yüklənmədi: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToRoomDetails(MonitorRoomStatistics room) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RoomMonitorsScreen(
          roomStats: room,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AdminDrawer(),
      appBar: AppBar(
        title: const Text('Otaqlar üzrə statistika'),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header with date selector
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.primaryBlue.withOpacity(0.1),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedExamDate,
                    decoration: const InputDecoration(
                      labelText: 'İmtahan tarixi',
                      border: OutlineInputBorder(),
                    ),
                    items: _examDates.map((date) {
                      return DropdownMenuItem(
                        value: date,
                        child: Text(date),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedExamDate = value;
                        });
                        _loadRoomStatistics(value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: () {
                    if (_selectedExamDate != null) {
                      _loadRoomStatistics(_selectedExamDate!);
                    }
                  },
                  icon: const Icon(Icons.refresh),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.errorRed,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.errorRed,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (_selectedExamDate != null) {
                  _loadRoomStatistics(_selectedExamDate!);
                }
              },
              child: const Text('Yenidən cəhd et'),
            ),
          ],
        ),
      );
    }

    if (_roomStatistics.isEmpty) {
      return const Center(
        child: Text('Bu tarix üçün otaq statistikası tapılmadı'),
      );
    }

    return _buildRoomsList();
  }

  Widget _buildRoomsList() {
    // Sort rooms by registration percentage (problematic first)
    final sortedRooms = List<MonitorRoomStatistics>.from(_roomStatistics)
      ..sort((a, b) =>
          a.registrationPercentage.compareTo(b.registrationPercentage));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedRooms.length + 1, // +1 for summary
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildSummaryCard();
        }

        final room = sortedRooms[index - 1];
        return _buildRoomCard(room);
      },
    );
  }

  Widget _buildSummaryCard() {
    final totalRooms = _roomStatistics.length;
    final totalMonitors =
        _roomStatistics.fold<int>(0, (sum, room) => sum + room.allPersonCount);
    final totalRegistered =
        _roomStatistics.fold<int>(0, (sum, room) => sum + room.regPersonCount);
    final overallPercentage =
        totalMonitors > 0 ? (totalRegistered / totalMonitors) * 100 : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryBlue, AppColors.lightBlue],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Ümumi statistika',
            style: AppTextStyles.h3.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'Otaqlar',
                  totalRooms.toString(),
                  Icons.meeting_room,
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  'Nəzarətçilər',
                  totalMonitors.toString(),
                  Icons.people,
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  'Qeydiyyat',
                  '${overallPercentage.toStringAsFixed(1)}%',
                  Icons.check_circle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: AppTextStyles.h2.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          title,
          style: AppTextStyles.caption.copyWith(
            color: Colors.white70,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRoomCard(MonitorRoomStatistics room) {
    final registrationRate = room.registrationPercentage;
    final isProblematic = registrationRate < 85.0;
    final isExcellent = registrationRate >= 95.0;

    Color statusColor;
    IconData statusIcon;

    if (isExcellent) {
      statusColor = AppColors.successGreen;
      statusIcon = Icons.check_circle;
    } else if (isProblematic) {
      statusColor = AppColors.errorRed;
      statusIcon = Icons.warning;
    } else {
      statusColor = AppColors.warning;
      statusIcon = Icons.info;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _navigateToRoomDetails(room),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: statusColor.withOpacity(0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Room code (left)
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 20),
                    const SizedBox(height: 2),
                    Text(
                      room.roomId.toString(),
                      style: AppTextStyles.caption.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Room info (center)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.roomName,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${room.regPersonCount}/${room.allPersonCount} nəzarətçi',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              // Statistics (right)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${registrationRate.toStringAsFixed(1)}%',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
