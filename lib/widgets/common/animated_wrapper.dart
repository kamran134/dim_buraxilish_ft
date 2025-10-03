import 'package:flutter/material.dart';

/// Переиспользуемая анимационная обертка с fade и scale анимациями
class AnimatedWrapper extends StatefulWidget {
  final Widget child;
  final Duration fadeDuration;
  final Duration scaleDuration;
  final Curve fadeCurve;
  final Curve scaleCurve;
  final double scaleBegin;
  final double scaleEnd;
  final bool autoStart;

  const AnimatedWrapper({
    super.key,
    required this.child,
    this.fadeDuration = const Duration(milliseconds: 800),
    this.scaleDuration = const Duration(milliseconds: 600),
    this.fadeCurve = Curves.easeIn,
    this.scaleCurve = Curves.elasticOut,
    this.scaleBegin = 0.8,
    this.scaleEnd = 1.0,
    this.autoStart = true,
  });

  @override
  State<AnimatedWrapper> createState() => _AnimatedWrapperState();
}

class _AnimatedWrapperState extends State<AnimatedWrapper>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();

    if (widget.autoStart) {
      _startAnimations();
    }
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: widget.fadeDuration,
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: widget.scaleDuration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: widget.fadeCurve,
    ));

    _scaleAnimation = Tween<double>(
      begin: widget.scaleBegin,
      end: widget.scaleEnd,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: widget.scaleCurve,
    ));
  }

  void _startAnimations() {
    _fadeController.forward();
    _scaleController.forward();
  }

  /// Метод для программного запуска анимаций
  void startAnimations() {
    _startAnimations();
  }

  /// Метод для сброса анимаций
  void resetAnimations() {
    _fadeController.reset();
    _scaleController.reset();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}
