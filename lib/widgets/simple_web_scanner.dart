import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'manual_input_dialog.dart';

// Импорт только для веб-платформы
import 'dart:html' as html;
import 'dart:async';

class SimpleWebScanner extends StatefulWidget {
  final Function(String) onScan;
  final VoidCallback onClose;
  final String? scannerType;

  const SimpleWebScanner({
    super.key,
    required this.onScan,
    required this.onClose,
    this.scannerType = 'participant',
  });

  @override
  State<SimpleWebScanner> createState() => _SimpleWebScannerState();
}

class _SimpleWebScannerState extends State<SimpleWebScanner> {
  html.VideoElement? _video;
  html.MediaStream? _stream;
  bool _isScanning = false;
  bool _cameraReady = false;
  String _errorMessage = '';
  List<String> _debugLogs = [];

  @override
  void initState() {
    super.initState();
    _addLog('INFO: Komponentin başladılması');
    _addLog('INFO: Platforma: ${kIsWeb ? "Web" : "Mobile"}');
    _addLog('INFO: User-Agent: ${html.window.navigator.userAgent}');
    _addLog('INFO: URL: ${html.window.location.href}');
    _addLog('INFO: Protocol: ${html.window.location.protocol}');
    _startCamera();
  }

  void _addLog(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    final logEntry = '[$timestamp] $message';
    debugPrint(logEntry);
    setState(() {
      _debugLogs.add(logEntry);
      if (_debugLogs.length > 20) {
        _debugLogs.removeAt(0);
      }
    });
  }

  @override
  void dispose() {
    _stopCamera();
    super.dispose();
  }

  Future<void> _startCamera() async {
    _addLog('INFO: _startCamera() başladı');

    if (!kIsWeb) {
      _addLog('ERROR: Platform web deyil');
      return;
    }

    try {
      _addLog('INFO: Navigator məlumatları yoxlanılır...');

      // Проверяем поддержку медиа устройств
      if (html.window.navigator.mediaDevices == null) {
        _addLog('ERROR: MediaDevices API dəstəklənmir');
        setState(() {
          _errorMessage = 'Bu brauzer kamera dəstəkləmir';
        });
        return;
      }

      _addLog('INFO: MediaDevices API mövcuddur');

      _addLog('INFO: getUserMedia mövcuddur');

      // Проверяем безопасное соединение
      final protocol = html.window.location.protocol;
      final hostname = html.window.location.hostname;
      _addLog('INFO: Protocol: $protocol, Hostname: $hostname');

      if (protocol != 'https:' &&
          hostname != 'localhost' &&
          hostname != '127.0.0.1') {
        _addLog('ERROR: Təhlükəsiz bağlantı tələb olunur');
        setState(() {
          _errorMessage =
              'Kamera üçün HTTPS lazımdır.\nTəhlükəsiz bağlantı istifadə edin.';
        });
        return;
      }

      _addLog('INFO: Bağlantı təhlükəsizdir');

      // Получаем список доступных устройств
      try {
        _addLog('INFO: Əlçatan cihazlar yoxlanılır...');
        final devices =
            await html.window.navigator.mediaDevices!.enumerateDevices();
        final videoDevices =
            devices.where((device) => device.kind == 'videoinput').toList();
        _addLog('INFO: Video cihazları tapıldı: ${videoDevices.length}');

        for (int i = 0; i < videoDevices.length; i++) {
          final device = videoDevices[i];
          _addLog(
              'INFO: Cihaz $i: ${device.label.isNotEmpty ? device.label : "Adı yoxdur"} (${device.deviceId})');
        }
      } catch (e) {
        _addLog('WARNING: Cihazlar siyahısı alınmadı: $e');
      }

      // Получаем доступ к камере
      final constraints = {
        'video': {
          'facingMode': 'environment',
          'width': {'ideal': 640},
          'height': {'ideal': 480},
        }
      };

      _addLog('INFO: Kamera icazəsi tələb edilir...');
      _addLog('INFO: Constraints: $constraints');

      _stream =
          await html.window.navigator.mediaDevices!.getUserMedia(constraints);
      _addLog('INFO: Kamera axını alındı');

      // Получаем информацию о треках
      final videoTracks = _stream!.getVideoTracks();
      _addLog('INFO: Video trek sayı: ${videoTracks.length}');

      if (videoTracks.isNotEmpty) {
        final track = videoTracks.first;
        _addLog('INFO: Video trek: ${track.label}, Aktiv: ${track.enabled}');
        final settings = track.getSettings();
        _addLog('INFO: Trek parametrləri: $settings');
      }

      // Создаем видео элемент
      _addLog('INFO: Video element yaradılır...');
      _video = html.VideoElement()
        ..autoplay = true
        ..muted = true
        ..setAttribute('playsinline', 'true')
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover';

      _video!.srcObject = _stream;
      _addLog('INFO: Video elementi kameraya bağlandı');

      _addLog('INFO: Video metadata gözlənilir...');
      await _video!.onLoadedMetadata.first;
      _addLog('INFO: Video metadata yükləndi');

      setState(() {
        _cameraReady = true;
      });

      // Добавляем видео в DOM и настраиваем для отображения
      _video!
        ..id = 'flutter-camera-video'
        ..style.position = 'fixed'
        ..style.top = '0'
        ..style.left = '0'
        ..style.width = '100vw'
        ..style.height = '100vh'
        ..style.objectFit = 'cover'
        ..style.zIndex = '-1'; // Помещаем под Flutter интерфейс

      html.document.body!.append(_video!);
      _addLog('INFO: Video element DOM-a əlavə edildi və göstərilir');

      // Получаем размеры видео
      _addLog(
          'INFO: Video ölçüləri: ${_video!.videoWidth}x${_video!.videoHeight}');

      // Начинаем сканирование
      _addLog('INFO: Skan dövrü başlayır...');
      _startScanLoop();

      _addLog('SUCCESS: Kamera uğurla başladıldı!');
    } catch (e) {
      _addLog('ERROR: Kamera xətası baş verdi: $e');

      String errorMsg;
      final errorString = e.toString();

      if (errorString.contains('NotAllowedError') ||
          errorString.contains('Permission denied')) {
        // Определяем тип браузера для более точных инструкций
        final userAgent = html.window.navigator.userAgent.toLowerCase();
        String instructions;

        if (userAgent.contains('crios') || userAgent.contains('chrome')) {
          // Chrome на iOS или Android
          instructions = '''
📱 Chrome brauzerdə kamera icazəsi:

1. Ünvan sətrindəki 🔒 simvoluna toxunun
2. "Kamera" seçin
3. "İcazə ver" seçin
4. Səhifəni yeniləyin (⟳)

Və ya:
• Brauzer Parametrləri → Sayt parametrləri → eservices.dim.gov.az → Kamera → İcazə ver''';
        } else if (userAgent.contains('safari')) {
          // Safari
          instructions = '''
📱 Safari brauzerdə kamera icazəsi:

1. Ünvan sətrindəki 🔒 simvoluna toxunun  
2. "Kamera üçün icazə ver" seçin
3. Səhifəni yeniləyin

Və ya:
• Parametrlər → Safari → Kamera → Bu sayt üçün soruş''';
        } else {
          // Универсальные инструкции
          instructions = '''
📱 Kamera icazəsi vermək üçün:

1. Ünvan sətrindəki 🔒 və ya ⚙️ simvoluna toxunun
2. "Kamera" seçimini tapın  
3. "İcazə ver" və ya "Allow" seçin
4. Səhifəni yeniləyin

⚠️ İcazə vermədən kamera işləməyəcək!''';
        }

        errorMsg = 'Kamera icazəsi tələb olunur!\n\n$instructions';
        _addLog('ERROR: NotAllowedError - İcazə rədd edildi');
        _addLog(
            'INFO: Browser: ${userAgent.contains('crios') ? 'Chrome iOS' : userAgent.contains('safari') ? 'Safari' : 'Naməlum'}');
      } else if (errorString.contains('NotFoundError')) {
        errorMsg =
            'Kamera tapılmadı.\nCihazınızda kamera olduğundan əmin olun.';
        _addLog('ERROR: NotFoundError - Kamera tapılmadı');
      } else if (errorString.contains('NotReadableError')) {
        errorMsg = 'Kamera başqa proqram tərəfindən istifadə olunur.';
        _addLog('ERROR: NotReadableError - Kamera məşğuldur');
      } else if (errorString.contains('OverconstrainedError')) {
        errorMsg = 'Kamera parametrləri dəstəklənmir.\nBaşqa kamera seçin.';
        _addLog('ERROR: OverconstrainedError - Parametrlər uyğun deyil');
      } else if (errorString.contains('TypeError')) {
        errorMsg =
            'Brauzer kamera API dəstəkləmir.\nDaha yeni brauzer istifadə edin.';
        _addLog('ERROR: TypeError - API dəstəklənmir');
      } else {
        errorMsg = 'Kamera xətası:\n$errorString';
        _addLog('ERROR: Naməlum xəta: $errorString');
      }

      setState(() {
        _errorMessage = errorMsg;
      });
      debugPrint('Camera error: $e');
    }
  }

  void _startScanLoop() {
    _addLog('INFO: _startScanLoop() çağırıldı');

    if (!_cameraReady || _video == null) {
      _addLog('WARNING: Kamera hazır deyil və ya video null');
      return;
    }

    setState(() {
      _isScanning = true;
    });

    _addLog('INFO: Skan dövrü aktiv edildi');

    // Создаем canvas для захвата кадров
    final canvas = html.CanvasElement();
    final context = canvas.context2D;
    _addLog('INFO: Canvas yaradıldı');

    // Простая попытка сканирования каждые 500ms
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!_isScanning || _video == null) {
        _addLog('INFO: Skan dövrü dayandırıldı');
        timer.cancel();
        return;
      }

      try {
        // Проверяем размеры видео
        final videoWidth = _video!.videoWidth;
        final videoHeight = _video!.videoHeight;

        if (videoWidth == 0 || videoHeight == 0) {
          _addLog('WARNING: Video ölçüləri 0: ${videoWidth}x${videoHeight}');
          return;
        }

        // Захватываем кадр
        canvas.width = videoWidth;
        canvas.height = videoHeight;
        context.drawImage(_video!, 0, 0);

        // Логируем только каждые 10 секунд
        if (DateTime.now().millisecondsSinceEpoch % 10000 < 500) {
          _addLog('INFO: Kadr çəkildi: ${videoWidth}x${videoHeight}');
        }

        // Получаем данные изображения для QR декодера
        // final imageData = context.getImageData(0, 0, canvas.width!, canvas.height!);

        // Здесь в реальной реализации должен быть QR декодер
        // Для простоты пока просто эмулируем сканирование
        _simulateQRDetection();
      } catch (e) {
        _addLog('ERROR: Skan xətası: $e');
        debugPrint('Scan error: $e');
      }
    });
  }

  void _simulateQRDetection() {
    // В реальной реализации здесь был бы QR декодер
    // Пока что просто показываем интерфейс

    // Логируем только каждые 30 секунд
    if (DateTime.now().millisecondsSinceEpoch % 30000 < 500) {
      _addLog('INFO: QR dekoder simulyasiyası işləyir');
    }
  }

  void _stopCamera() {
    _addLog('INFO: Kamera dayandırılır...');

    setState(() {
      _isScanning = false;
      _cameraReady = false;
    });

    if (_stream != null) {
      final tracks = _stream!.getTracks();
      _addLog('INFO: ${tracks.length} trek dayandırılır');
      tracks.forEach((track) {
        track.stop();
        _addLog('INFO: Trek dayandırıldı: ${track.label}');
      });
      _stream = null;
    }

    if (_video != null) {
      _video!.remove();
      _video = null;
      _addLog('INFO: Video elementi silindi');
    }

    _addLog('INFO: Kamera tamamilə dayandırıldı');
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

  void _showPermissionHelp() {
    final userAgent = html.window.navigator.userAgent.toLowerCase();
    String browserName;
    List<String> steps;

    if (userAgent.contains('crios')) {
      browserName = 'Chrome (iOS)';
      steps = [
        '1. Ünvan sətrindəki 🔒 simvoluna toxunun',
        '2. "Kamera" seçimini tapın',
        '3. "İcazə ver" seçin',
        '4. Səhifəni yeniləyin (⟳ düyməsi)',
        '',
        'Alternativ:',
        '• Chrome Parametrləri → Sayt Parametrləri',
        '• eservices.dim.gov.az tapın',
        '• Kamera → İcazə ver',
      ];
    } else if (userAgent.contains('safari')) {
      browserName = 'Safari';
      steps = [
        '1. Ünvan sətrindəki 🔒 simvoluna toxunun',
        '2. "Kamera üçün icazə ver" seçin',
        '3. Səhifəni yeniləyin',
        '',
        'Alternativ:',
        '• Parametrlər → Safari',
        '• Kamera → Bu sayt üçün soruş',
      ];
    } else {
      browserName = 'Brauzer';
      steps = [
        '1. Ünvan sətrindəki 🔒 və ya ⚙️ toxunun',
        '2. "Kamera" seçimini tapın',
        '3. "İcazə ver" seçin',
        '4. Səhifəni yeniləyin',
        '',
        '⚠️ Hər brauzerdə fərqli ola bilər',
      ];
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$browserName - Kamera İcazəsi'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '📱 Kamera icazəsi vermək üçün:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              ...steps.map((step) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      step,
                      style: const TextStyle(height: 1.4),
                    ),
                  )),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '💡 İcazə verdikdən sonra "Yenidən cəhd et" düyməsini basın',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.blue,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anladım'),
          ),
        ],
      ),
    );
  }

  void _showDebugLogs() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Diaqnostika Logları'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Column(
            children: [
              Text(
                'Loglar sayı: ${_debugLogs.length}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _debugLogs.length,
                  itemBuilder: (context, index) {
                    final log = _debugLogs[index];
                    Color textColor = Colors.black;
                    if (log.contains('ERROR:')) {
                      textColor = Colors.red;
                    } else if (log.contains('WARNING:')) {
                      textColor = Colors.orange;
                    } else if (log.contains('SUCCESS:')) {
                      textColor = Colors.green;
                    } else if (log.contains('INFO:')) {
                      textColor = Colors.blue;
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: SelectableText(
                        log,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: textColor,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Копируем логи в буфер обмена
              Clipboard.setData(ClipboardData(text: _debugLogs.join('\n')));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Loglar kopyalandı')),
              );
            },
            child: const Text('Kopyala'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bağla'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Камера показывается через HTML video элемент в фоне

          // Интерфейс сканирования
          if (_cameraReady) ...[
            // Затемнение по краям для фокуса на центре
            Container(
              color: Colors.black.withOpacity(0.5),
            ),

            // Центральная область для сканирования
            Center(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.green,
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    // Углы рамки
                    ...List.generate(4, (index) {
                      final isTop = index < 2;
                      final isLeft = index % 2 == 0;
                      return Positioned(
                        top: isTop ? -1.5 : null,
                        bottom: !isTop ? -1.5 : null,
                        left: isLeft ? -1.5 : null,
                        right: !isLeft ? -1.5 : null,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            border: Border(
                              top: isTop
                                  ? const BorderSide(
                                      color: Colors.green, width: 3)
                                  : BorderSide.none,
                              bottom: !isTop
                                  ? const BorderSide(
                                      color: Colors.green, width: 3)
                                  : BorderSide.none,
                              left: isLeft
                                  ? const BorderSide(
                                      color: Colors.green, width: 3)
                                  : BorderSide.none,
                              right: !isLeft
                                  ? const BorderSide(
                                      color: Colors.green, width: 3)
                                  : BorderSide.none,
                            ),
                          ),
                        ),
                      );
                    }),

                    // Центральное отверстие (прозрачность для камеры)
                    Center(
                      child: Container(
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Инструкция внизу
            Positioned(
              bottom: 200,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '📱 QR kodu kamera görüşünə yerləşdirin\nAvtomatik tanıma veb versiyasında məhduddur',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],

          // Сообщение об ошибке или загрузке
          if (!_cameraReady)
            Center(
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
                    Icon(
                      _cameraReady
                          ? Icons.qr_code_scanner
                          : _errorMessage.isNotEmpty
                              ? Icons.error
                              : Icons.camera_alt,
                      size: 64,
                      color: _cameraReady
                          ? Colors.green
                          : _errorMessage.isNotEmpty
                              ? Colors.red
                              : Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _cameraReady
                          ? 'Kamera Hazırdır!'
                          : _errorMessage.isNotEmpty
                              ? 'Xəta baş verdi'
                              : 'Kamera yüklənir...',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: SingleChildScrollView(
                        child: Text(
                          _cameraReady
                              ? 'Kamera işləyir, ancaq QR dekoder Flutter veb versiyasında məhduddur.\nQR kodunuzu əl ilə daxil edin.'
                              : _errorMessage.isNotEmpty
                                  ? _errorMessage
                                  : 'Kamera hazırlanır...',
                          style: TextStyle(
                            fontSize: _errorMessage.contains('📱') ? 14 : 16,
                            color: Colors.black54,
                            height: 1.5,
                            fontFamily: _errorMessage.contains('📱')
                                ? 'monospace'
                                : null,
                          ),
                          textAlign: TextAlign.left,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_errorMessage.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                _addLog('INFO: Yenidən cəhd düyməsinə basıldı');
                                setState(() {
                                  _errorMessage = '';
                                  _cameraReady = false;
                                });
                                _startCamera();
                              },
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('Yenidən cəhd et'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          if (_errorMessage.contains('NotAllowedError') ||
                              _errorMessage.contains('📱')) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  _addLog(
                                      'INFO: Parametrlər düyməsinə basıldı');
                                  _showPermissionHelp();
                                },
                                icon: const Icon(Icons.settings, size: 18),
                                label: const Text('Kömək'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                    ] else ...[
                      // Кнопка ручного ввода для случая ошибок
                      ElevatedButton.icon(
                        onPressed: () {
                          _addLog('INFO: Əl ilə daxiletmə düyməsinə basıldı');
                          _showManualInput();
                        },
                        icon: const Icon(Icons.keyboard),
                        label: const Text('QR kodu əllə daxil et'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
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
                    ],
                  ],
                ),
              ),
            ),

          // Верхние кнопки управления
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
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
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: _showDebugLogs,
                      icon: const Icon(
                        Icons.bug_report,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _cameraReady
                          ? Colors.green.withOpacity(0.8)
                          : Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _cameraReady ? 'KAMERA AKTİV' : 'WEB VERSIYA',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Кнопка ручного ввода внизу (когда камера работает)
          if (_cameraReady)
            Positioned(
              bottom: 80,
              left: 20,
              right: 20,
              child: Center(
                child: ElevatedButton.icon(
                  onPressed: () {
                    _addLog('INFO: Əl ilə daxiletmə düyməsinə basıldı');
                    _showManualInput();
                  },
                  icon: const Icon(Icons.keyboard),
                  label: const Text('QR kodu əllə daxil et'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
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
              ),
            ),
        ],
      ),
    );
  }
}
