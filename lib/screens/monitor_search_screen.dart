import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../design/app_text_styles.dart';
import '../models/monitor_models.dart';
import '../providers/auth_provider.dart';
import '../services/http_service.dart';

class MonitorSearchScreen extends StatefulWidget {
  const MonitorSearchScreen({super.key});

  @override
  State<MonitorSearchScreen> createState() => _MonitorSearchScreenState();
}

class _MonitorSearchScreenState extends State<MonitorSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final HttpService _httpService = HttpService();

  List<Monitor> _results = [];
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _results = [];
        _errorMessage = null;
      });
      return;
    }
    _debounce =
        Timer(const Duration(milliseconds: 400), () => _search(value.trim()));
  }

  Future<void> _search(String term) async {
    final examDate = context.read<AuthProvider>().authData?.examDate ?? '';
    if (examDate.isEmpty) {
      setState(() => _errorMessage = 'İmtahan tarixi müəyyən edilmədi');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await _httpService.searchMonitorsByName(
        searchTerm: term,
        examDate: examDate,
      );
      setState(() {
        _results = results;
        _isLoading = false;
        if (results.isEmpty)
          _errorMessage = '"$term" axtarışı üzrə nəticə tapılmadı';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Xəta baş verdi';
      });
    }
  }

  Future<void> _callPhone(String phone) async {
    final cleaned = phone.trim();
    if (cleaned.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: cleaned);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label kopyalandı'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF059669),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDarkMode ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF059669),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('İmtahan rəhbəri axtar',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Search field
          Container(
            color: const Color(0xFF059669),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: Colors.white),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                hintText: 'Ad, soyad və ya ata adı ilə axtar...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _results = [];
                            _errorMessage = null;
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withOpacity(0.15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
                ),
              ),
            ),
          ),

          // Results
          Expanded(
            child: _buildBody(isDarkMode),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(bool isDarkMode) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF059669)),
      );
    }

    if (_searchController.text.trim().length < 2) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search,
                size: 64, color: Colors.grey.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text(
              'Axtarmaq üçün ən az 2 simvol daxil edin',
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null && _results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off,
                size: 64, color: Colors.grey.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _results.length,
      itemBuilder: (context, index) =>
          _buildResultCard(_results[index], isDarkMode),
    );
  }

  Widget _buildResultCard(Monitor monitor, bool isDarkMode) {
    final phones = (monitor.phone ?? '')
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    final cardColor = isDarkMode ? const Color(0xFF1F2937) : Colors.white;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF111827);
    final subColor = isDarkMode ? Colors.white70 : const Color(0xFF6B7280);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name
            Text(
              '${monitor.lastName} ${monitor.firstName} ${monitor.middleName}'
                  .trim(),
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),

            const SizedBox(height: 8),

            // Work number — big and prominent
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'İş № ${monitor.workNumber}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _copyToClipboard(
                      monitor.workNumber.toString(), 'İş nömrəsi'),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF059669)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.copy,
                            size: 14, color: Color(0xFF059669)),
                        const SizedBox(width: 4),
                        Text(
                          'Kopyala',
                          style: TextStyle(
                            color: const Color(0xFF059669),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            if (monitor.roomName.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.meeting_room, size: 14, color: subColor),
                  const SizedBox(width: 4),
                  Text(monitor.roomName,
                      style: AppTextStyles.bodySmall.copyWith(color: subColor)),
                  const SizedBox(width: 12),
                  if (monitor.buildingName.isNotEmpty) ...[
                    Icon(Icons.business, size: 14, color: subColor),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        monitor.buildingName,
                        style:
                            AppTextStyles.bodySmall.copyWith(color: subColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],

            // Phone numbers
            if (phones.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children:
                    phones.map((phone) => _buildPhoneChip(phone)).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneChip(String phone) {
    return InkWell(
      onTap: () => _callPhone(phone),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF0EA5E9).withOpacity(0.1),
          border: Border.all(color: const Color(0xFF0EA5E9)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.phone, size: 14, color: Color(0xFF0EA5E9)),
            const SizedBox(width: 6),
            Text(
              phone,
              style: const TextStyle(
                color: Color(0xFF0EA5E9),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
