import 'dart:html' as html;
import 'dart:js_interop' as js;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WebQRScanner extends StatefulWidget {
  final Function(String) onScan;
  final VoidCallback onClose;

  const WebQRScanner({
    super.key,
    required this.onScan,
    required this.onClose,
  });

  @override
  State<WebQRScanner> createState() => _WebQRScannerState();
}

class _WebQRScannerState extends State<WebQRScanner> {
  html.VideoElement? _video;
  html.MediaStream? _stream;
  bool _isInitialized = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      // Проверяем поддержку getUserMedia
      if (!html.window.navigator.mediaDevices.isSupported!) {
        setState(() {
          _errorMessage = 'Kamera dəstəklənmir';
        });
        return;
      }

      // Создаем видео элемент
      _video = html.VideoElement()
        ..autoplay = true
        ..muted = true
        ..setAttribute('playsinline', 'true')
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover';

      // Запрашиваем доступ к камере
      final constraints = {
        'video': {
          'facingMode': 'environment', // Задняя камера
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
        }
      };

      _stream =
          await html.window.navigator.mediaDevices.getUserMedia(constraints);

      if (_stream != null) {
        _video!.srcObject = _stream;

        // Ждем загрузки видео
        await _video!.onLoadedMetadata.first;

        setState(() {
          _isInitialized = true;
        });

        // Добавляем видео элемент в DOM
        final container = html.querySelector('#camera-container');
        if (container != null) {
          container.children.clear();
          container.children.add(_video!);
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Kamera açıla bilmədi: ${e.toString()}';
      });
      debugPrint('Camera error: $e');
    }
  }

  @override
  void dispose() {
    _disposeCamera();
    super.dispose();
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
    showDialog(
      context: context,
      builder: (context) {
        String input = '';
        return AlertDialog(
          title: const Text('QR kodunu daxil edin'),
          content: TextField(
            onChanged: (value) => input = value,
            decoration: const InputDecoration(
              hintText: 'QR kod və ya mətn',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Ləğv et'),
            ),
            ElevatedButton(
              onPressed: () {
                if (input.isNotEmpty) {
                  Navigator.pop(context);
                  widget.onScan(input);
                }
              },
              child: const Text('Təsdiqlə'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Camera container
          Container(
            width: double.infinity,
            height: double.infinity,
            child: _isInitialized
                ? HtmlElementView(
                    viewType: 'camera-container',
                    onPlatformViewCreated: (int viewId) {
                      // Веб-специфичная реализация
                    },
                  )
                : _errorMessage.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.camera_alt_outlined,
                              size: 64,
                              color: Colors.white54,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _showManualInput,
                              icon: const Icon(Icons.keyboard),
                              label: const Text('Əllə daxil et'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      )
                    : const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                        ),
                      ),
          ),

          // Overlay with scanning frame
          if (_isInitialized)
            Container(
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
                      // Corner decorations
                      _buildCornerDecoration(Alignment.topLeft),
                      _buildCornerDecoration(Alignment.topRight),
                      _buildCornerDecoration(Alignment.bottomLeft),
                      _buildCornerDecoration(Alignment.bottomRight),
                    ],
                  ),
                ),
              ),
            ),

          // Top controls
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Back button
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
                  // Web info
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        'WEB',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom controls
          Positioned(
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
                        'QR kodunu kameraya yönəldin\n(Veb versiyası - əllə daxil etmək məsləhətdir)',
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
          ),
        ],
      ),
    );
  }

  Widget _buildCornerDecoration(Alignment alignment) {
    return Positioned(
      top: alignment.y < 0 ? -2 : null,
      bottom: alignment.y > 0 ? -2 : null,
      left: alignment.x < 0 ? -2 : null,
      right: alignment.x > 0 ? -2 : null,
      child: SizedBox(
        width: 20,
        height: 20,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: alignment.y < 0
                  ? const BorderSide(color: Colors.green, width: 4)
                  : BorderSide.none,
              bottom: alignment.y > 0
                  ? const BorderSide(color: Colors.green, width: 4)
                  : BorderSide.none,
              left: alignment.x < 0
                  ? const BorderSide(color: Colors.green, width: 4)
                  : BorderSide.none,
              right: alignment.x > 0
                  ? const BorderSide(color: Colors.green, width: 4)
                  : BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }
}
