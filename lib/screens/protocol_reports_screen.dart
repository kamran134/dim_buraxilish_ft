/// Protocol Reports Screen for Admins
/// Allows admins/superadmins to view and filter all protocol notes
///
/// Author: GitHub Copilot
/// Date: 2025-10-13

import 'package:flutter/material.dart';
import '../models/protocol_models.dart';
import '../services/protocol_service.dart';
import '../services/http_service.dart';
import '../utils/date_formatter.dart';
import '../widgets/common/common_widgets.dart';
import '../design/app_colors.dart';
import '../design/app_text_styles.dart';

class ProtocolReportsScreen extends StatefulWidget {
  const ProtocolReportsScreen({super.key});

  @override
  State<ProtocolReportsScreen> createState() => _ProtocolReportsScreenState();
}

class _ProtocolReportsScreenState extends State<ProtocolReportsScreen> {
  late ProtocolService _protocolService;
  List<ProtocolNote> _protocols = [];
  bool _isLoading = false;
  bool _showFilters = false;

  // Filter controllers
  final _binaController = TextEditingController();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _examDateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _protocolService = ProtocolService(HttpService());

    // Set today's date as default exam date filter
    final today = DateTime.now();
    _examDateController.text = DateFormatter.formatDateToAz(today);

    _loadProtocols();
  }

  @override
  void dispose() {
    _binaController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _examDateController.dispose();
    super.dispose();
  }

  Future<void> _loadProtocols() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Build filter parameters
      int? bina;
      if (_binaController.text.isNotEmpty) {
        bina = int.tryParse(_binaController.text);
      }

      String? startDate;
      if (_startDateController.text.isNotEmpty) {
        // Convert from DD.MM.YYYY to YYYY-MM-DD
        final parts = _startDateController.text.split('.');
        if (parts.length == 3) {
          startDate =
              '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
        }
      }

      String? endDate;
      if (_endDateController.text.isNotEmpty) {
        // Convert from DD.MM.YYYY to YYYY-MM-DD
        final parts = _endDateController.text.split('.');
        if (parts.length == 3) {
          endDate =
              '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
        }
      }

      String? examDate;
      if (_examDateController.text.isNotEmpty) {
        // Convert from DD.MM.YYYY to YYYY-MM-DD
        final parts = _examDateController.text.split('.');
        if (parts.length == 3) {
          examDate =
              '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
        }
      }

      final response = await _protocolService.getProtocols(
        pageSize: 1000, // Get all protocols
        bina: bina,
        startDate: startDate,
        endDate: endDate,
        examDate: examDate,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (response.success && response.data != null) {
          setState(() {
            _protocols = response.data!.data;
          });

          if (_protocols.isEmpty) {
            _showSnackBar('Seçilmiş filtrə uyğun protokol tapılmadı');
          } else {
            _showSnackBar('${_protocols.length} protokol tapıldı');
          }
        } else {
          _showSnackBar(response.message ?? 'Protokollar yüklənmədi',
              isError: true);
        }
      }
    } catch (e) {
      print('Error loading protocols: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showSnackBar('Protokollar yükləməkdə xəta baş verdi', isError: true);
      }
    }
  }

  void _clearFilters() {
    setState(() {
      _binaController.clear();
      _startDateController.clear();
      _endDateController.clear();
      _examDateController.clear();
      _protocols.clear();
    });
  }

  Future<void> _selectDate(TextEditingController controller) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('az', 'AZ'),
    );

    if (pickedDate != null) {
      controller.text = DateFormatter.formatDateToAz(pickedDate);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: GradientBackground(
        gradientType: GradientType.supervisor,
        isDarkMode: isDarkMode,
        child: SafeArea(
          child: Column(
            children: [
              // Header
              ScreenHeader(
                title: 'Protokol hesabatları',
                showBackButton: false,
              ),

              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Filter Toggle Button
                      _buildFilterToggle(isDarkMode),

                      // Filter Panel
                      if (_showFilters) _buildFiltersPanel(isDarkMode),

                      const SizedBox(height: 16),

                      // Protocols List
                      Expanded(
                        child: _buildProtocolsList(isDarkMode),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterToggle(bool isDarkMode) {
    return AnimatedWrapper(
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        child: ElevatedButton.icon(
          onPressed: () {
            setState(() {
              _showFilters = !_showFilters;
            });
          },
          icon: Icon(_showFilters ? Icons.filter_list_off : Icons.filter_list),
          label: Text(_showFilters ? 'Filterləri gizlə' : 'Filterləri göstər'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFiltersPanel(bool isDarkMode) {
    return AnimatedWrapper(
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(isDarkMode ? 0.1 : 0.9),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filterlər',
              style: AppTextStyles.heading3.copyWith(
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            // Building Number Filter
            TextField(
              controller: _binaController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Bina nömrəsi',
                hintText: 'Məs. 1, 2, 3...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.8),
                prefixIcon: const Icon(Icons.business),
              ),
            ),
            const SizedBox(height: 12),

            // Exam Date Filter
            TextField(
              controller: _examDateController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'İmtahan tarixi',
                hintText: 'DD.MM.YYYY',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.8),
                prefixIcon: const Icon(Icons.event),
                suffixIcon: const Icon(Icons.calendar_today),
              ),
              onTap: () => _selectDate(_examDateController),
            ),
            const SizedBox(height: 12),

            // Date Range Filters
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _startDateController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Başlama tarixi',
                      hintText: 'DD.MM.YYYY',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.8),
                      prefixIcon: const Icon(Icons.date_range),
                    ),
                    onTap: () => _selectDate(_startDateController),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _endDateController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Son tarix',
                      hintText: 'DD.MM.YYYY',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.8),
                      prefixIcon: const Icon(Icons.date_range),
                    ),
                    onTap: () => _selectDate(_endDateController),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _loadProtocols,
                    icon: const Icon(Icons.search),
                    label: const Text('Axtar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.clear),
                    label: const Text('Təmizlə'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          isDarkMode ? Colors.white : Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProtocolsList(bool isDarkMode) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Protokollar yüklənir...'),
          ],
        ),
      );
    }

    if (_protocols.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Protokol tapılmadı',
              style: AppTextStyles.heading3.copyWith(
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Filter parametrlərini dəyişib yenidən cəhd edin',
              style: AppTextStyles.bodyLarge.copyWith(
                color: Colors.grey[400],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Results Header
        AnimatedWrapper(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.analytics,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '${_protocols.length} protokol tapıldı',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                // TODO: Add Excel export button here
                IconButton(
                  onPressed: () {
                    _showSnackBar('Excel eksport funksiyası əlavə ediləcək');
                  },
                  icon: const Icon(Icons.file_download),
                  color: AppColors.primary,
                  tooltip: 'Excel-ə eksport et',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Protocols List
        Expanded(
          child: ListView.builder(
            itemCount: _protocols.length,
            itemBuilder: (context, index) {
              final protocol = _protocols[index];
              return AnimatedWrapper(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(isDarkMode ? 0.1 : 0.9),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with building and type
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.business,
                                  size: 16,
                                  color: AppColors.secondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Bina ${protocol.bina}',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.secondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              protocol.noteTypeName,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Protocol note content
                      Text(
                        protocol.note,
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Dates
                      Row(
                        children: [
                          Icon(
                            Icons.event,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'İmtahan: ${DateFormatter.formatISOToAz(protocol.examDate)}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Əlavə edilib: ${DateFormatter.formatISOToAz(protocol.createdAt)}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                          if (protocol.updatedAt != protocol.createdAt) ...[
                            const SizedBox(width: 12),
                            Icon(
                              Icons.edit,
                              size: 16,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Redaktə: ${DateFormatter.formatISOToAz(protocol.updatedAt)}',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: Colors.grey[500],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
