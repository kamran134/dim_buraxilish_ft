import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../design/app_colors.dart';
import '../design/app_text_styles.dart';
import '../models/exam_models.dart';
import '../models/participant_models.dart';
import '../providers/auth_provider.dart';
import '../providers/offline_database_provider.dart';
import '../services/exam_session_switcher.dart';
import '../services/http_service.dart';
import '../widgets/common/common_widgets.dart';
import 'main_screen.dart';
import 'real_dashboard_screen.dart';

/// Loading state of the exam list itself (the `GET /exams` call).
enum _ListState { loading, loaded, error, empty }

/// Full-screen overlay phase shown while selecting an exam: flushing the
/// unsynced queue, then downloading the offline database for the newly
/// picked exam. Mirrors the overlay that used to live on the login screen —
/// moved here because the download now happens after picking an exam, not
/// at login.
enum _Phase {
  idle,
  syncingQueue,
  downloading,
  success,
  partialData,
  emptyData,
  networkError,
}

class ExamSelectScreen extends StatefulWidget {
  const ExamSelectScreen({super.key});

  @override
  State<ExamSelectScreen> createState() => _ExamSelectScreenState();
}

class _ExamSelectScreenState extends State<ExamSelectScreen> {
  final HttpService _httpService = HttpService();

  _ListState _listState = _ListState.loading;
  String _listError = '';
  List<ExamDto> _exams = [];

  // Used to mark the currently active exam card / session chip.
  int? _currentExamId;
  int? _currentSessionId;
  String? _currentImtTarix;

  _Phase _phase = _Phase.idle;
  int _downloadedParticipants = 0;
  int _downloadedSupervisors = 0;
  String _partialErrorMessage = '';
  bool _partialMissingParticipants = false;

  static const _azMonths = [
    '',
    'yanvar',
    'fevral',
    'mart',
    'aprel',
    'may',
    'iyun',
    'iyul',
    'avqust',
    'sentyabr',
    'oktyabr',
    'noyabr',
    'dekabr',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadExams());
  }

  String _formatExamDate(String iso) {
    try {
      final date = DateTime.parse(iso);
      return '${date.day} ${_azMonths[date.month]} ${date.year}';
    } catch (_) {
      return iso;
    }
  }

  Future<void> _loadExams() async {
    setState(() {
      _listState = _ListState.loading;
      _listError = '';
    });

    final stored = await _httpService.getExamDetailsFromStorage();
    _currentExamId = stored?.examId;
    _currentSessionId = stored?.sessionId;
    _currentImtTarix = stored?.imtTarix;

    final result = await _httpService.getExams();
    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _listState = _ListState.error;
        _listError = result.message.isNotEmpty
            ? result.message
            : 'İmtahanları əldə etmək mümkün olmadı';
      });
      return;
    }

    setState(() {
      _exams = result.data;
      _listState = _exams.isEmpty ? _ListState.empty : _ListState.loaded;
    });
  }

  Future<void> _onSessionTap(ExamDto exam, ExamSessionDto session) async {
    if (session.legacyImtTarix == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Təsdiq'),
        content: Text(
            '${exam.name} · ${session.label} seçilsin? Offline baza yenidən yüklənəcək.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Ləğv et'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Seç'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;
    await _selectSession(exam, session);
  }

  Future<void> _selectSession(ExamDto exam, ExamSessionDto session) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final offlineProvider =
        Provider.of<OfflineDatabaseProvider>(context, listen: false);

    // a)-c): flush the unsynced queue, wipe the offline tables, persist the
    // newly picked exam+session and update AuthProvider — shared with
    // RealDashboardScreen's and HomeScreen's session switchers via
    // ExamSessionSwitcher so this logic only exists once.
    setState(() => _phase = _Phase.syncingQueue);
    await ExamSessionSwitcher.persistSelection(
      authProvider: authProvider,
      httpService: _httpService,
      examId: exam.id,
      examName: exam.name,
      sessionId: session.id,
      sessionLabel: session.label,
      legacyImtTarix: session.legacyImtTarix!,
      sessions: exam.sessions
          .map((s) => ExamSessionSummary(
                id: s.id,
                label: s.label,
                legacyImtTarix: s.legacyImtTarix,
              ))
          .toList(),
      onUnsyncedRemaining: (remaining) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '$remaining qeydiyyat hələ göndərilməyib — itməyəcək, internet olanda göndəriləcək'),
            backgroundColor: Colors.orange.shade800,
            duration: const Duration(seconds: 4),
          ),
        );
      },
    );

    if (!mounted) return;

    // d) Download the offline database — same branch by role that used to
    // run right after login, with the same progress/errors surfaced for
    // BOTH roles (the admin path used to swallow download errors silently).
    setState(() => _phase = _Phase.downloading);
    await _performDownload(offlineProvider, authProvider);
  }

  Future<void> _performDownload(
    OfflineDatabaseProvider offlineProvider,
    AuthProvider authProvider,
  ) async {
    final outcome = await ExamSessionSwitcher.downloadForRole(
      authProvider: authProvider,
      offlineProvider: offlineProvider,
    );
    if (!mounted) return;

    switch (outcome.result) {
      case SessionSwitchResult.success:
        if (authProvider.canAccessDashboard) {
          // Admin download has no participant/supervisor counts to show —
          // navigate straight away, same as before.
          _navigateToTarget(authProvider);
          return;
        }
        setState(() {
          _phase = _Phase.success;
          _downloadedParticipants = outcome.participantCount;
          _downloadedSupervisors = outcome.supervisorCount;
        });
        await Future.delayed(const Duration(milliseconds: 1500));
        if (!mounted) return;
        _navigateToTarget(authProvider);
      case SessionSwitchResult.partialSuccess:
        setState(() {
          _partialErrorMessage = outcome.message ?? '';
          _partialMissingParticipants = outcome.missingParticipants;
          _phase = _Phase.partialData;
        });
      case SessionSwitchResult.emptyData:
        setState(() => _phase = _Phase.emptyData);
      case SessionSwitchResult.networkError:
        setState(() => _phase = _Phase.networkError);
    }
  }

  Future<void> _retryDownload() async {
    final offlineProvider =
        Provider.of<OfflineDatabaseProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    setState(() => _phase = _Phase.downloading);
    await _performDownload(offlineProvider, authProvider);
  }

  void _continueDespitePartial() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _navigateToTarget(authProvider);
  }

  void _navigateToTarget(AuthProvider authProvider) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            authProvider.canAccessDashboard
                ? const RealDashboardScreen()
                : const MainScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = _phase != _Phase.idle;
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('İmtahan seçin', style: AppTextStyles.appBarTitle),
            backgroundColor: AppColors.lightBlue,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.lightBlue, AppColors.darkBlue],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Expanded(child: _buildBody()),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: LogoutButton(
                      type: LogoutButtonType.settings,
                      title: 'Çıxış',
                      textColor: Colors.white,
                      iconColor: Colors.white,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (busy) _buildPhaseOverlay(),
      ],
    );
  }

  Widget _buildBody() {
    switch (_listState) {
      case _ListState.loading:
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      case _ListState.error:
        return _buildMessageState(
          icon: Icons.wifi_off_rounded,
          title: 'Xəta baş verdi',
          subtitle: _listError,
          actionLabel: 'Yenidən cəhd et',
          onAction: _loadExams,
        );
      case _ListState.empty:
        return _buildMessageState(
          icon: Icons.event_busy_rounded,
          title: 'Aktiv imtahan yoxdur',
          subtitle: '',
        );
      case _ListState.loaded:
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          itemCount: _exams.length,
          itemBuilder: (context, index) => _buildExamCard(_exams[index]),
        );
    }
  }

  Widget _buildMessageState({
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 56),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppTextStyles.h4.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExamCard(ExamDto exam) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final disabled = !exam.hasSelectableSession;
    final busy = _phase != _Phase.idle;
    final isActiveExam = _currentExamId != null
        ? exam.id == _currentExamId
        : (_currentImtTarix != null &&
            _currentImtTarix!.isNotEmpty &&
            exam.sessions.any((s) => s.legacyImtTarix == _currentImtTarix));

    return Opacity(
      opacity: disabled ? 0.55 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border:
              isActiveExam ? Border.all(color: Colors.white, width: 2) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      exam.name,
                      style: AppTextStyles.cardTitle.copyWith(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  if (isActiveExam)
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(Icons.check_circle,
                          color: AppColors.success, size: 20),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _formatExamDate(exam.examDate),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isDark ? Colors.white70 : AppColors.textSecondary,
                ),
              ),
              if (exam.shortName != null && exam.shortName!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(exam.shortName!, style: AppTextStyles.caption),
              ],
              if (disabled) ...[
                const SizedBox(height: 6),
                Text(
                  'Köhnə sistemlə əlaqələndirilməyib',
                  style:
                      AppTextStyles.caption.copyWith(color: AppColors.error),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: exam.sessions
                    .map((session) => _buildSessionChip(
                          exam,
                          session,
                          isDark: isDark,
                          busy: busy,
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionChip(
    ExamDto exam,
    ExamSessionDto session, {
    required bool isDark,
    required bool busy,
  }) {
    final sessionDisabled = session.legacyImtTarix == null;
    final isActiveSession = _currentSessionId != null
        ? session.id == _currentSessionId && exam.id == _currentExamId
        : (_currentImtTarix != null &&
            _currentImtTarix!.isNotEmpty &&
            session.legacyImtTarix == _currentImtTarix);

    final baseColor = isDark ? AppColors.surfaceDark : Colors.white;
    final activeColor = isDark
        ? AppColors.splashLightBlue.withOpacity(0.25)
        : AppColors.primaryBlue.withOpacity(0.12);

    return Opacity(
      opacity: sessionDisabled ? 0.5 : 1.0,
      child: Material(
        color: isActiveSession ? activeColor : baseColor,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: (sessionDisabled || busy)
              ? null
              : () => _onSessionTap(exam, session),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isActiveSession
                    ? AppColors.primaryBlue
                    : (isDark ? Colors.white24 : Colors.black12),
                width: isActiveSession ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isActiveSession)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.check_circle,
                        color: AppColors.success, size: 16),
                  ),
                Text(
                  session.label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight:
                        isActiveSession ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhaseOverlay() {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
      child: Container(
        color: Colors.black.withOpacity(0.45),
        child: Center(
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 32),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 40,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: _buildOverlayContent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlayContent() {
    switch (_phase) {
      case _Phase.syncingQueue:
        return _overlaySpinner(
          title: 'Göndərilməmiş məlumat göndərilir',
          subtitle: 'Zəhmət olmasa gözləyin...',
        );
      case _Phase.downloading:
        return _overlaySpinner(
          title: 'Məlumatlar yüklənir',
          subtitle: 'Zəhmət olmasa gözləyin...',
        );
      case _Phase.success:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 64),
            const SizedBox(height: 24),
            const Text(
              'Baza yükləndi!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$_downloadedParticipants iştirakçı · $_downloadedSupervisors nəzarətçi',
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 14,
                decoration: TextDecoration.none,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        );
      case _Phase.partialData:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 56),
            const SizedBox(height: 20),
            const Text(
              'Natamam yükləndi',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.none,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '$_partialErrorMessage\nZəhmət olmasa bir daha cəhd edin\nvə ya qərargahdan məlumatları dəqiqləşdirin.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 13,
                decoration: TextDecoration.none,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _retryDownload,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Yenidən cəhd et'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _continueDespitePartial,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                _partialMissingParticipants
                    ? 'Bu imtahanda iştirakçı yoxdur'
                    : 'Bu imtahanda nəzarətçi yoxdur',
              ),
            ),
          ],
        );
      case _Phase.emptyData:
        return _overlayError(
          icon: Icons.warning_amber_rounded,
          title: 'Məlumat tapılmadı',
          subtitle:
              'Server bu bina üçün məlumat qaytarmadı.\nTarixin düzgünlüyünü və internet bağlantısını yoxlayın.',
        );
      case _Phase.networkError:
        return _overlayError(
          icon: Icons.wifi_off_rounded,
          title: 'İnternet bağlantısı kəsildi',
          subtitle:
              'Məlumatlar yüklənmədi.\nBağlantını yoxlayıb yenidən cəhd edin.',
        );
      case _Phase.idle:
        return const SizedBox.shrink();
    }
  }

  Widget _overlaySpinner({required String title, required String subtitle}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
          ),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            decoration: TextDecoration.none,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 13,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }

  Widget _overlayError({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 56),
        const SizedBox(height: 20),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.none,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withOpacity(0.75),
            fontSize: 13,
            decoration: TextDecoration.none,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        ElevatedButton.icon(
          onPressed: _retryDownload,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Yenidən cəhd et'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    );
  }
}
