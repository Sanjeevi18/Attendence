import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SnackbarUtils {
  // Standard success snackbar
  static void showSuccess(String message, {String? title}) {
    Get.snackbar(
      title ?? 'Success',
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: const Color(0xFF4CAF50),
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      icon: const Icon(Icons.check_circle, color: Colors.white, size: 24),
      shouldIconPulse: false,
      boxShadows: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // Standard error snackbar
  static void showError(String message, {String? title}) {
    Get.snackbar(
      title ?? 'Error',
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: const Color(0xFFF44336),
      colorText: Colors.white,
      duration: const Duration(seconds: 4),
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      icon: const Icon(Icons.error, color: Colors.white, size: 24),
      shouldIconPulse: false,
      boxShadows: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // Standard warning snackbar
  static void showWarning(String message, {String? title}) {
    Get.snackbar(
      title ?? 'Warning',
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: const Color(0xFFFF9800),
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      icon: const Icon(Icons.warning, color: Colors.white, size: 24),
      shouldIconPulse: false,
      boxShadows: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // Standard info snackbar
  static void showInfo(String message, {String? title}) {
    Get.snackbar(
      title ?? 'Info',
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: const Color(0xFF2196F3),
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      icon: const Icon(Icons.info, color: Colors.white, size: 24),
      shouldIconPulse: false,
      boxShadows: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // Bottom positioned snackbars for specific cases
  static void showBottomSuccess(String message, {String? title}) {
    Get.snackbar(
      title ?? 'Success',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF4CAF50),
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      icon: const Icon(Icons.check_circle, color: Colors.white, size: 24),
      shouldIconPulse: false,
      boxShadows: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 8,
          offset: const Offset(0, -4),
        ),
      ],
    );
  }

  static void showBottomError(String message, {String? title}) {
    Get.snackbar(
      title ?? 'Error',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFFF44336),
      colorText: Colors.white,
      duration: const Duration(seconds: 4),
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      icon: const Icon(Icons.error, color: Colors.white, size: 24),
      shouldIconPulse: false,
      boxShadows: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 8,
          offset: const Offset(0, -4),
        ),
      ],
    );
  }

  static void showBottomWarning(String message, {String? title}) {
    Get.snackbar(
      title ?? 'Warning',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFFFF9800),
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      icon: const Icon(Icons.warning, color: Colors.white, size: 24),
      shouldIconPulse: false,
      boxShadows: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 8,
          offset: const Offset(0, -4),
        ),
      ],
    );
  }

  static void showBottomInfo(String message, {String? title}) {
    Get.snackbar(
      title ?? 'Info',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF2196F3),
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      icon: const Icon(Icons.info, color: Colors.white, size: 24),
      shouldIconPulse: false,
      boxShadows: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 8,
          offset: const Offset(0, -4),
        ),
      ],
    );
  }
}
