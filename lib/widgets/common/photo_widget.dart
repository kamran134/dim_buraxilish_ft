import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Переиспользуемый виджет для отображения фото из base64 строки
class PhotoWidget extends StatelessWidget {
  final String? photoData;
  final IconData placeholderIcon;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Color? placeholderColor;
  final double? placeholderSize;

  const PhotoWidget({
    super.key,
    this.photoData,
    this.placeholderIcon = Icons.person,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholderColor = Colors.grey,
    this.placeholderSize = 60,
  });

  /// Фабричный метод для фото участника
  factory PhotoWidget.participant({
    String? photoData,
    double? width,
    double? height,
  }) {
    return PhotoWidget(
      photoData: photoData,
      placeholderIcon: Icons.person,
      width: width,
      height: height,
    );
  }

  /// Фабричный метод для фото нэзарэтчи
  factory PhotoWidget.supervisor({
    String? photoData,
    double? width,
    double? height,
  }) {
    return PhotoWidget(
      photoData: photoData,
      placeholderIcon: Icons.supervisor_account,
      width: width,
      height: height,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (photoData == null || photoData!.isEmpty) {
      return _buildPlaceholder();
    }

    try {
      // Try to decode as base64 if it looks like base64 data
      if (photoData!.startsWith('data:image') || photoData!.length > 100) {
        // Remove data URL prefix if present
        String base64String = photoData!;
        if (photoData!.startsWith('data:image')) {
          base64String = photoData!.split(',').last;
        }

        // Decode base64 to bytes
        final Uint8List bytes = base64Decode(base64String);

        return Image.memory(
          bytes,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (context, error, stackTrace) {
            if (kDebugMode) {
              debugPrint('[Photo] Error loading photo: $error');
            }
            return _buildPlaceholder();
          },
        );
      } else {
        // If not base64, show placeholder
        return _buildPlaceholder();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Photo] Error decoding photo: $e');
      }
      return _buildPlaceholder();
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      child: Center(
        child: Icon(
          placeholderIcon,
          size: placeholderSize,
          color: placeholderColor,
        ),
      ),
    );
  }
}
