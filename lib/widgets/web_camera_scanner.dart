import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'manual_input_dialog.dart';

// Импорт только для веб-платформы
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

class WebCameraScanner extends StatefulWidget {
  final Function(String) onScan;
  final VoidCallback onClose;
  final String? scannerType;

  const WebCameraScanner({
    super.key,
    required this.onScan,
    required this.onClose,
    this.scannerType = 'participant',
  });

  @override
  State<WebCameraScanner> createState() => _WebCameraScannerState();
}

class _WebCameraScannerState extends State<WebCameraScanner> {
  html.VideoElement? _video;
  html.MediaStream? _stream;
  bool _isInitialized = false;
  String _errorMessage = '';
  String _statusMessage = 'Kamera başladılır...';

  @override
  void initState() {
    super.initState();
    // Не запускаем камеру автоматически
    setState(() {
      _statusMessage = 'Kamera açmaq üçün düyməni basın';
    });
  }

  @override
  void dispose() {
    _disposeCamera();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    if (!kIsWeb) return;

    setState(() {
      _statusMessage = 'Kamera icazəsi istənir...';
      _errorMessage = ''; // Очищаем предыдущие ошибки
    });

    try {
      // Проверяем поддержку getUserMedia
      if (html.window.navigator.mediaDevices == null) {
        setState(() {
          _errorMessage = 'Bu brauzer kamera dəstəkləmir';
        });
        return;
      }

      // Запрашиваем доступ к камере - здесь должен появиться диалог браузера!
      final constraints = {
        'video': {
          'facingMode': 'environment', // Задняя камера предпочтительна
          'width': {'ideal': 1280, 'max': 1920},
          'height': {'ideal': 720, 'max': 1080},
        }
      };

      setState(() {
        _statusMessage = 'Brauzer pəncərəsində icazə verin...';
      });

      _stream =
          await html.window.navigator.mediaDevices!.getUserMedia(constraints);

      if (_stream != null) {
        setState(() {
          _statusMessage = 'Kamera hazırlanır...';
        });
        await _setupVideo();
      }
    } catch (e) {
      String errorMsg;
      if (e.toString().contains('NotAllowedError') ||
          e.toString().contains('Permission denied')) {
        errorMsg =
            'Kamera icazəsi rədd edildi.\n\nBrauzer parametrlərində kamera icazəsini aktivləşdirin və yenidən cəhd edin.';
      } else if (e.toString().contains('NotFoundError')) {
        errorMsg =
            'Kamera tapılmadı.\n\nCihazınızda kamera olduğundan və başqa proqram tərəfindən istifadə olunmadığından əmin olun.';
      } else if (e.toString().contains('NotReadableError')) {
        errorMsg =
            'Kamera başqa proqram tərəfindən istifadə olunur.\n\nDigər tab-ları və ya kamera proqramlarını bağlayın.';
      } else {
        errorMsg = 'Kamera xətası:\n${e.toString()}';
      }

      setState(() {
        _errorMessage = errorMsg;
      });
      debugPrint('Camera error: $e');
    }
  }

  Future<void> _setupVideo() async {
    try {
      // Создаем видео элемент
      _video = html.VideoElement()
        ..autoplay = true
        ..muted = true
        ..setAttribute('playsinline', 'true')
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover';

      _video!.srcObject = _stream;

      // Ждем загрузки видео
      await _video!.onLoadedMetadata.first;

      setState(() {
        _isInitialized = true;
        _statusMessage = 'Kamera hazırdır!';
      });

      // Регистрируем view для Flutter Web
      ui_web.platformViewRegistry.registerViewFactory(
        'camera-view-${widget.hashCode}',
        (int viewId) => _video!,
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Kamera qurula bilmədi: ${e.toString()}';
      });
      debugPrint('Video setup error: $e');
    }
  }

  void _disposeCamera() {
    if (_stream != null) {
      _stream!.getTracks().forEach((track) {
        track.stop();
      });
      _stream = null;
    }

    if (_video != null) {
      _video!.pause();
      _video!.srcObject = null;
      _video = null;
    }
  }

  void _showManualInput() {
    if (widget.scannerType == 'supervisor') {
      ManualInputDialog.showSupervisorDialog(
        context,
        (input) {
          widget.onScan(input);
        },
      );
    } else {
      ManualInputDialog.showParticipantDialog(
        context,
        (input) {
          widget.onScan(input);
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Основной контент
          if (_isInitialized)
            _buildCameraView()
          else if (_errorMessage.isNotEmpty)
            _buildErrorView()
          else if (_stream == null)
            _buildStartScreen()
          else
            _buildLoadingView(),

          // Overlay с рамкой сканирования (только если камера работает)
          if (_isInitialized) _buildScanningOverlay(),

          // Верхние кнопки управления
          _buildTopControls(),

          // Нижние кнопки управления
          _buildBottomControls(),
        ],
      ),
    );
  }

  Widget _buildCameraView() {
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: HtmlElementView(
        viewType: 'camera-view-${widget.hashCode}',
      ),
    );
  }

  Widget _buildStartScreen() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.camera_alt,
              size: 64,
              color: Colors.blue,
            ),
            const SizedBox(height: 16),
            const Text(
              'Veb Kamera Skaneri',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'QR kodları skanlamaq üçün kameraya icazə verin.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _initializeCamera,
              icon: const Icon(Icons.videocam),
              label: const Text('Kameranı Aç'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _showManualInput,
              icon: const Icon(Icons.keyboard),
              label: const Text('Əllə daxil et'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '💡 Brauzer kamera icazəsi istəyəcək',
              style: TextStyle(
                fontSize: 14,
                color: Colors.orange,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.camera_alt_outlined,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              'Kamera Problemi',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black54,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  onPressed: _initializeCamera,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Yenidən cəhd et'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _showManualInput,
                  icon: const Icon(Icons.keyboard),
                  label: const Text('Əllə daxil et'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              _statusMessage,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Kamera hazırlanır...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanningOverlay() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
      ),
      child: Center(
        child: Container(
          width: 280,
          height: 280,
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.white,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              // Угловые маркеры
              ..._buildCornerMarkers(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCornerMarkers() {
    return [
      // Верхний левый
      const Positioned(
        top: -2,
        left: -2,
        child: SizedBox(
          width: 20,
          height: 20,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.green, width: 4),
                left: BorderSide(color: Colors.green, width: 4),
              ),
            ),
          ),
        ),
      ),
      // Остальные углы...
      const Positioned(
        top: -2,
        right: -2,
        child: SizedBox(
          width: 20,
          height: 20,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.green, width: 4),
                right: BorderSide(color: Colors.green, width: 4),
              ),
            ),
          ),
        ),
      ),
      const Positioned(
        bottom: -2,
        left: -2,
        child: SizedBox(
          width: 20,
          height: 20,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.green, width: 4),
                left: BorderSide(color: Colors.green, width: 4),
              ),
            ),
          ),
        ),
      ),
      const Positioned(
        bottom: -2,
        right: -2,
        child: SizedBox(
          width: 20,
          height: 20,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.green, width: 4),
                right: BorderSide(color: Colors.green, width: 4),
              ),
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildTopControls() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Кнопка назад
            Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                onPressed: widget.onClose,
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                ),
              ),
            ),
            const Spacer(),
            // Индикатор веб-версии
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'WEB KAMERA',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isInitialized)
                const Text(
                  'QR kodu kameraya yönəldin\n(Veb versiyası - avtomatik skanləmə məhduddur)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _showManualInput,
                icon: const Icon(Icons.keyboard),
                label: const Text('Əllə daxil et'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.9),
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
