import 'package:flutter/material.dart';
import '../models/exam_details_dto.dart';
import '../models/participant_light_dto.dart';
import '../models/supervisor_detail_dto.dart';
import '../services/statistics_service.dart';
import '../design/app_colors.dart';
import '../design/app_text_styles.dart';

class BuildingDetailsScreen extends StatefulWidget {
  final ExamDetailsDto building;
  final String examDate;

  const BuildingDetailsScreen({
    Key? key,
    required this.building,
    required this.examDate,
  }) : super(key: key);

  @override
  State<BuildingDetailsScreen> createState() => _BuildingDetailsScreenState();
}

class _BuildingDetailsScreenState extends State<BuildingDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final StatisticsService _statisticsService = StatisticsService();

  List<ParticipantLightDto> _participants = [];
  List<SupervisorDetailDto> _supervisors = [];
  bool _isLoadingParticipants = false;
  bool _isLoadingSupervisors = false;
  String? _participantsError;
  String? _supervisorsError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadParticipants(),
      _loadSupervisors(),
    ]);
  }

  Future<void> _loadParticipants() async {
    setState(() {
      _isLoadingParticipants = true;
      _participantsError = null;
    });

    try {
      // Проверяем параметры перед запросом
      final buildingCode = widget.building.kodBina ?? '';
      print('DEBUG BuildingDetails: Loading participants');
      print('DEBUG BuildingDetails: buildingCode = "$buildingCode"');
      print('DEBUG BuildingDetails: examDate = "${widget.examDate}"');

      if (buildingCode.isEmpty) {
        throw Exception('Kod bina boşdur');
      }

      final result = await _statisticsService.getAllParticipantsInBuilding(
        buildingCode,
        widget.examDate,
      );

      if (result.success && result.data != null) {
        setState(() {
          _participants = result.data!;
        });
      } else {
        setState(() {
          _participantsError = result.message;
        });
      }
    } catch (e) {
      setState(() {
        _participantsError = 'Xəta baş verdi: $e';
      });
    } finally {
      setState(() {
        _isLoadingParticipants = false;
      });
    }
  }

  Future<void> _loadSupervisors() async {
    setState(() {
      _isLoadingSupervisors = true;
      _supervisorsError = null;
    });

    try {
      // Проверяем параметры перед запросом
      final buildingCode = widget.building.kodBina ?? '';
      print('DEBUG BuildingDetails: Loading supervisors');
      print('DEBUG BuildingDetails: buildingCode = "$buildingCode"');
      print('DEBUG BuildingDetails: examDate = "${widget.examDate}"');

      if (buildingCode.isEmpty) {
        throw Exception('Kod bina boşdur');
      }

      final result = await _statisticsService.getAllSupervisorsInBuilding(
        buildingCode,
        widget.examDate,
      );

      if (result.success && result.data != null) {
        setState(() {
          _supervisors = result.data!;
        });
      } else {
        setState(() {
          _supervisorsError = result.message;
        });
      }
    } catch (e) {
      setState(() {
        _supervisorsError = 'Xəta baş verdi: $e';
      });
    } finally {
      setState(() {
        _isLoadingSupervisors = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.building.adBina ?? 'Bina',
              style: AppTextStyles.appBarTitle.copyWith(fontSize: 16),
            ),
            Text(
              'Kod: ${widget.building.kodBina}',
              style: AppTextStyles.caption.copyWith(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600),
          unselectedLabelStyle: AppTextStyles.body1,
          tabs: [
            Tab(
              icon: const Icon(Icons.school),
              text: 'İştirakçılar (${_participants.length})',
            ),
            Tab(
              icon: const Icon(Icons.supervisor_account),
              text: 'Nəzarətçilər (${_supervisors.length})',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildParticipantsTab(),
          _buildSupervisorsTab(),
        ],
      ),
    );
  }

  Widget _buildParticipantsTab() {
    if (_isLoadingParticipants) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    if (_participantsError != null) {
      return _buildErrorWidget(_participantsError!, _loadParticipants);
    }

    if (_participants.isEmpty) {
      return _buildEmptyWidget('Bu binada iştirakçı tapılmadı');
    }

    return Container(
      color: Colors.grey[100],
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _participants.length,
        itemBuilder: (context, index) {
          final participant = _participants[index];
          return _buildParticipantCard(participant);
        },
      ),
    );
  }

  Widget _buildSupervisorsTab() {
    if (_isLoadingSupervisors) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    if (_supervisorsError != null) {
      return _buildErrorWidget(_supervisorsError!, _loadSupervisors);
    }

    if (_supervisors.isEmpty) {
      return _buildEmptyWidget('Bu binada nəzarətçi tapılmadı');
    }

    return Container(
      color: Colors.grey[100],
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _supervisors.length,
        itemBuilder: (context, index) {
          final supervisor = _supervisors[index];
          return _buildSupervisorCard(supervisor);
        },
      ),
    );
  }

  Widget _buildParticipantCard(ParticipantLightDto participant) {
    final isRegistered = participant.isRegistered;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isRegistered ? AppColors.successGreen : AppColors.errorRed,
          width: 2,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Статус регистрации
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color:
                    isRegistered ? AppColors.successGreen : AppColors.errorRed,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 16),

            // Информация участника
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    participant.fullName,
                    style: AppTextStyles.body1.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'İş №: ${participant.isN ?? "N/A"}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textGrey,
                    ),
                  ),
                  if (participant.yer != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Yer: ${participant.yer}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Иконка статуса
            Icon(
              isRegistered ? Icons.check_circle : Icons.cancel,
              color: isRegistered ? AppColors.successGreen : AppColors.errorRed,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupervisorCard(SupervisorDetailDto supervisor) {
    final isRegistered = supervisor.isRegistered;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isRegistered ? AppColors.successGreen : AppColors.errorRed,
          width: 2,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Статус регистрации
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color:
                    isRegistered ? AppColors.successGreen : AppColors.errorRed,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 16),

            // Информация наблюдателя
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    supervisor.fullName,
                    style: AppTextStyles.body1.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Kart №: ${supervisor.cardNumber ?? "N/A"}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textGrey,
                    ),
                  ),
                  if (supervisor.phone != null &&
                      supervisor.phone!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Telefon: ${supervisor.phone}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Иконка статуса
            Icon(
              isRegistered ? Icons.check_circle : Icons.cancel,
              color: isRegistered ? AppColors.successGreen : AppColors.errorRed,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String message, VoidCallback onRetry) {
    return Container(
      color: Colors.grey[100],
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
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
                'Xəta baş verdi',
                style: AppTextStyles.h3.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextStyles.body1.copyWith(
                  color: AppColors.textGrey,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Təkrar cəhd et'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyWidget(String message) {
    return Container(
      color: Colors.grey[100],
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inbox_outlined,
                size: 64,
                color: AppColors.textGrey,
              ),
              const SizedBox(height: 16),
              Text(
                'Məlumat yoxdur',
                style: AppTextStyles.h3.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextStyles.body1.copyWith(
                  color: AppColors.textGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
