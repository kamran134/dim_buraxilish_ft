import 'package:flutter/material.dart';
import '../design/app_colors.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final bool forceLight; // Принудительное использование светлой темы

  const CustomTextField({
    Key? key,
    required this.controller,
    required this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.forceLight = false, // По умолчанию адаптируется к теме
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: forceLight || Theme.of(context).brightness == Brightness.light
              ? Colors.grey[600]
              : Colors.grey[400],
          fontSize: 16,
        ),
        prefixIcon: prefixIcon != null
            ? Icon(
                prefixIcon,
                color: forceLight ||
                        Theme.of(context).brightness == Brightness.light
                    ? Colors.grey[600]
                    : Colors.grey[400],
                size: 22,
              )
            : null,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor:
            forceLight || Theme.of(context).brightness == Brightness.light
                ? Colors.grey[50]
                : Colors.grey[800],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color:
                forceLight || Theme.of(context).brightness == Brightness.light
                    ? Colors.grey[300]!
                    : Colors.grey[600]!,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color:
                forceLight || Theme.of(context).brightness == Brightness.light
                    ? Colors.grey[300]!
                    : Colors.grey[600]!,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.deepBlue,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Colors.red,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Colors.red,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: forceLight || Theme.of(context).brightness == Brightness.light
            ? Colors
                .black87 // Тёмный цвет текста для светлой темы/принудительно
            : Colors.white, // Светлый цвет текста для темной темы
      ),
    );
  }
}
