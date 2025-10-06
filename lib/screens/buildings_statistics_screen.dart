import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/statistics/buildings_statistics_table.dart';
import '../design/app_colors.dart';
import '../design/app_text_styles.dart';
import '../services/statistics_service.dart';
import '../models/exam_statistics_dto.dart';

/// Экран для отображения детальной статистики по зданиям
class BuildingsStatisticsScreen extends StatefulWidget {
  /// Опциональная дата экзамена для предварительной загрузки
  final String? initialExamDate;

  const BuildingsStatisticsScreen({
    Key? key,
    this.initialExamDate,
  }) : super(key: key);

  @override
  State<BuildingsStatisticsScreen> createState() =>
      _BuildingsStatisticsScreenState();
}

class _BuildingsStatisticsScreenState extends State<BuildingsStatisticsScreen> {
  final StatisticsService _statisticsService = StatisticsService();
  List<ExamStatisticsDto> _statistics = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _selectedExamDate;
  List<String> _examDates = [];

  @override
  void initState() {
    super.initState();
    _selectedExamDate = widget.initialExamDate;
    _loadExamDates();
    if (_selectedExamDate != null) {
      _loadStatistics(_selectedExamDate!);
    }
  }

  Future<void> _loadExamDates() async {
    try {
      final result = await _statisticsService.getAllExamDates();
      if (result.success && result.data != null) {
        setState(() {
          _examDates = result.data!;
          if (_selectedExamDate == null && _examDates.isNotEmpty) {
            _selectedExamDate = _examDates.first;
            _loadStatistics(_selectedExamDate!);
          }
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки дат экзаменов: $e');
    }
  }

  Future<void> _loadStatistics(String examDate) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _statisticsService.getExamStatisticsByDate(examDate);
      if (result.success && result.data != null) {
        setState(() {
          _statistics = result.data!;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      appBar: AppBar(
        title: Text(
          'Binalar üzrə statistika',
          style: AppTextStyles.appBarTitle,
        ),
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          // Проверяем права доступа
          if (!(authProvider.isAdmin || authProvider.isSuperAdmin)) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 64,
                    color: Colors.white54,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Bu bölmə yalnız adminlər üçündür',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Селектор даты экзамена
              if (_examDates.isNotEmpty) _buildExamDateSelector(),

              // Контент
              Expanded(
                child: _buildContent(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildExamDateSelector() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today,
            color: Colors.white70,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            'İmtahan tarixi:',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButton<String>(
              value: _selectedExamDate,
              isExpanded: true,
              underline: Container(),
              dropdownColor: AppColors.primaryBlue,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              items: _examDates.map((date) {
                return DropdownMenuItem<String>(
                  value: date,
                  child: Text(date),
                );
              }).toList(),
              onChanged: (newDate) {
                if (newDate != null && newDate != _selectedExamDate) {
                  setState(() {
                    _selectedExamDate = newDate;
                  });
                  _loadStatistics(newDate);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              'Statistika yüklənir...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ],
        ),
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
              color: Colors.white54,
            ),
            const SizedBox(height: 16),
            Text(
              'Xəta baş verdi',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                if (_selectedExamDate != null) {
                  _loadStatistics(_selectedExamDate!);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
                foregroundColor: Colors.white,
              ),
              child: Text('Yenidən cəhd et'),
            ),
          ],
        ),
      );
    }

    if (_statistics.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.business_outlined,
              size: 64,
              color: Colors.white54,
            ),
            const SizedBox(height: 16),
            Text(
              'Bina statistikası yoxdur',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Başqa tarix seçin',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return BuildingsStatisticsTable(
      statistics: _statistics,
    );
  }
}
