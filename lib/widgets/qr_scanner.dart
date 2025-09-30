import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'manual_input_dialog.dart';

class QRScannerWidget extends StatefulWidget {
  final Function(String) onScan;
  final VoidCallback onClose;
  final String? scannerType; // 'participant' or 'supervisor'

  const QRScannerWidget({
    super.key,
    required this.onScan,
    required this.onClose,
    this.scannerType = 'participant',
  });

  @override
  State<QRScannerWidget> createState() => _QRScannerWidgetState();
}

class _QRScannerWidgetState extends State<QRScannerWidget>
    with TickerProviderStateMixin {
  late MobileScannerController controller;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  bool _isFlashOn = false;

  @override
  void initState() {
    super.initState();
    controller = MobileScannerController();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));

    _fadeController.forward();
  }

  @override
  void dispose() {
    controller.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _toggleFlash() async {
    await controller.toggleTorch();
    setState(() {
      _isFlashOn = !_isFlashOn;
    });
  }

  void _onDetect(BarcodeCapture barcodeCapture) {
    final List<Barcode> barcodes = barcodeCapture.barcodes;
    if (barcodes.isNotEmpty) {
      final barcode = barcodes.first;
      final String? code = barcode.rawValue;

      if (code != null && code.isNotEmpty) {
        HapticFeedback.mediumImpact();
        widget.onScan(code);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Scanner
          MobileScanner(
            controller: controller,
            onDetect: _onDetect,
          ),

          // Overlay with scanning frame
          FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
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
                                right:
                                    BorderSide(color: Colors.green, width: 4),
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
                                bottom:
                                    BorderSide(color: Colors.green, width: 4),
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
                                bottom:
                                    BorderSide(color: Colors.green, width: 4),
                                right:
                                    BorderSide(color: Colors.green, width: 4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
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
                  // Flash toggle
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: _toggleFlash,
                      icon: Icon(
                        _isFlashOn ? Icons.flash_on : Icons.flash_off,
                        color: _isFlashOn ? Colors.yellow : Colors.white,
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
                    const Text(
                      'QR kodu kameraya yönəldin',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (widget.scannerType == 'supervisor') {
                          ManualInputDialog.showSupervisorDialog(
                            context,
                            (input) {
                              Navigator.of(context).pop();
                              widget.onScan(input);
                            },
                          );
                        } else {
                          ManualInputDialog.showParticipantDialog(
                            context,
                            (input) {
                              Navigator.of(context).pop();
                              widget.onScan(input);
                            },
                          );
                        }
                      },
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
}
