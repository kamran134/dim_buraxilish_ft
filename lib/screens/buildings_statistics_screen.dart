import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/statistics/buildings_statistics_table.dart';
import '../widgets/statistics/active_slot_bar.dart';
import '../design/app_colors.dart';
import '../design/app_text_styles.dart';
import '../services/statistics_service.dart';
import '../models/exam_statistics_dto.dart';

/// Экран для отображения детальной статистики по зданиям.
/// Статистика всегда по выбранному слоту (см. API_slots.md) — своего выбора
/// даты у экрана нет, переключение слота через [ActiveSlotBar].
class BuildingsStatisticsScreen extends StatefulWidget {
  const BuildingsStatisticsScreen({Key? key}) : super(key: key);

  @override
  State<BuildingsStatisticsScreen> createState() =>
      _BuildingsStatisticsScreenState();
}

class _BuildingsStatisticsScreenState extends State<BuildingsStatisticsScreen> {
  final StatisticsService _statisticsService = StatisticsService();
  List<ExamStatisticsDto> _statistics = [];
  bool _isLoading = false;
  bool _noActiveSlot = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final examDate = await _statisticsService.getActiveSlotExamDate();
      if (!mounted) return;
      if (examDate == null) {
        setState(() {
          _noActiveSlot = true;
          _statistics = [];
        });
        return;
      }
      _noActiveSlot = false;

      final result = await _statisticsService.getExamStatisticsByDate(examDate);
      if (!mounted) return;
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
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Statistika yüklənmədi: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
              // Выбранный слот + переключатель
              ActiveSlotBar(onSwitched: _loadStatistics),

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

  Widget _buildContent() {
    if (_noActiveSlot && !_isLoading) {
      return const NoActiveSlotView();
    }

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
              onPressed: _loadStatistics,
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
              'Bu slot üçün məlumat tapılmadı',
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
