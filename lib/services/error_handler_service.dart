import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized error handling service for the app
class ErrorHandlerService {
  static final ErrorHandlerService _instance = ErrorHandlerService._internal();
  factory ErrorHandlerService() => _instance;
  ErrorHandlerService._internal();

  /// Handle errors and show appropriate user messages
  void handleError(
    dynamic error, {
    BuildContext? context,
    String? userMessage,
    bool showSnackBar = true,
    VoidCallback? onRetry,
  }) {
    final errorInfo = _parseError(error);
    
    // Log error for debugging
    _logError(error, errorInfo);
    
    // Show user-friendly message
    if (context != null && showSnackBar) {
      _showErrorSnackBar(
        context,
        userMessage ?? errorInfo.userMessage,
        onRetry: onRetry,
      );
    }
  }

  /// Handle async operations with error handling
  static Future<T?> handleAsync<T>(
    Future<T> Function() operation, {
    BuildContext? context,
    String? errorMessage,
    bool showError = true,
    T? defaultValue,
  }) async {
    try {
      return await operation();
    } catch (error) {
      if (showError) {
        ErrorHandlerService().handleError(
          error,
          context: context,
          userMessage: errorMessage,
        );
      }
      return defaultValue;
    }
  }

  /// Handle operations that might fail silently
  static void handleSilently(VoidCallback operation) {
    try {
      operation();
    } catch (error) {
      // Log but don't show to user
      developer.log(
        'Silent operation failed: $error',
        name: 'ErrorHandler',
        error: error,
      );
    }
  }

  /// Parse different types of errors
  ErrorInfo _parseError(dynamic error) {
    if (error is PostgrestException) {
      return _handleSupabaseError(error);
    } else if (error is AuthException) {
      return _handleAuthError(error);
    } else if (error is StorageException) {
      return _handleStorageError(error);
    } else if (error is Exception) {
      return _handleGenericException(error);
    } else {
      return ErrorInfo(
        type: ErrorType.unknown,
        code: 'UNKNOWN',
        message: error.toString(),
        userMessage: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  /// Handle Supabase database errors
  ErrorInfo _handleSupabaseError(PostgrestException error) {
    switch (error.code) {
      case '23505': // Unique violation
        return ErrorInfo(
          type: ErrorType.validation,
          code: error.code ?? '',
          message: error.message,
          userMessage: 'This information already exists. Please use different details.',
        );
      case '23503': // Foreign key violation
        return ErrorInfo(
          type: ErrorType.validation,
          code: error.code ?? '',
          message: error.message,
          userMessage: 'Invalid data provided. Please check your information.',
        );
      case '42P01': // Undefined table
        return ErrorInfo(
          type: ErrorType.configuration,
          code: error.code ?? '',
          message: error.message,
          userMessage: 'Service temporarily unavailable. Please try again later.',
        );
      default:
        return ErrorInfo(
          type: ErrorType.database,
          code: error.code ?? 'DB_ERROR',
          message: error.message,
          userMessage: 'Unable to save data. Please check your connection and try again.',
        );
    }
  }

  /// Handle authentication errors
  ErrorInfo _handleAuthError(AuthException error) {
    switch (error.message.toLowerCase()) {
      case String msg when msg.contains('invalid login'):
      case String msg when msg.contains('invalid credentials'):
        return ErrorInfo(
          type: ErrorType.authentication,
          code: 'INVALID_CREDENTIALS',
          message: error.message,
          userMessage: 'Invalid email or password. Please try again.',
        );
      case String msg when msg.contains('email not confirmed'):
        return ErrorInfo(
          type: ErrorType.authentication,
          code: 'EMAIL_NOT_CONFIRMED',
          message: error.message,
          userMessage: 'Please verify your email address before signing in.',
        );
      case String msg when msg.contains('too many requests'):
        return ErrorInfo(
          type: ErrorType.rateLimit,
          code: 'RATE_LIMIT',
          message: error.message,
          userMessage: 'Too many attempts. Please wait a moment before trying again.',
        );
      case String msg when msg.contains('weak password'):
        return ErrorInfo(
          type: ErrorType.validation,
          code: 'WEAK_PASSWORD',
          message: error.message,
          userMessage: 'Password is too weak. Please use a stronger password.',
        );
      default:
        return ErrorInfo(
          type: ErrorType.authentication,
          code: 'AUTH_ERROR',
          message: error.message,
          userMessage: 'Authentication failed. Please try again.',
        );
    }
  }

  /// Handle storage errors
  ErrorInfo _handleStorageError(StorageException error) {
    switch (error.error?.toLowerCase()) {
      case String msg when msg.contains('file too large'):
        return ErrorInfo(
          type: ErrorType.validation,
          code: 'FILE_TOO_LARGE',
          message: error.message,
          userMessage: 'File is too large. Please select a smaller file.',
        );
      case String msg when msg.contains('invalid file type'):
        return ErrorInfo(
          type: ErrorType.validation,
          code: 'INVALID_FILE_TYPE',
          message: error.message,
          userMessage: 'File type not supported. Please select a different file.',
        );
      case String msg when msg.contains('insufficient permissions'):
        return ErrorInfo(
          type: ErrorType.permission,
          code: 'INSUFFICIENT_PERMISSIONS',
          message: error.message,
          userMessage: 'Permission denied. Please try again or contact support.',
        );
      default:
        return ErrorInfo(
          type: ErrorType.storage,
          code: 'STORAGE_ERROR',
          message: error.message,
          userMessage: 'Failed to upload file. Please check your connection and try again.',
        );
    }
  }

  /// Handle generic exceptions
  ErrorInfo _handleGenericException(Exception error) {
    final message = error.toString();
    
    if (message.contains('SocketException') || message.contains('TimeoutException')) {
      return ErrorInfo(
        type: ErrorType.network,
        code: 'NETWORK_ERROR',
        message: message,
        userMessage: 'Network error. Please check your internet connection.',
      );
    }
    
    if (message.contains('FormatException')) {
      return ErrorInfo(
        type: ErrorType.validation,
        code: 'FORMAT_ERROR',
        message: message,
        userMessage: 'Invalid data format. Please check your input.',
      );
    }
    
    if (message.contains('Permission')) {
      return ErrorInfo(
        type: ErrorType.permission,
        code: 'PERMISSION_ERROR',
        message: message,
        userMessage: 'Permission required. Please grant the necessary permissions.',
      );
    }
    
    return ErrorInfo(
      type: ErrorType.generic,
      code: 'GENERIC_ERROR',
      message: message,
      userMessage: 'Something went wrong. Please try again.',
    );
  }

  /// Log error for debugging
  void _logError(dynamic error, ErrorInfo errorInfo) {
    if (kDebugMode) {
      developer.log(
        'Error: ${errorInfo.type.name} - ${errorInfo.code}',
        name: 'ErrorHandler',
        error: error,
        stackTrace: StackTrace.current,
      );
    }
    
    // In production, you might want to send to crash reporting service
    // like Crashlytics, Sentry, etc.
  }

  /// Show error snackbar to user
  void _showErrorSnackBar(
    BuildContext context,
    String message, {
    VoidCallback? onRetry,
  }) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        action: onRetry != null
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  /// Show success message
  static void showSuccess(BuildContext context, String message) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show info message
  static void showInfo(BuildContext context, String message) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show error dialog for critical errors
  static void showErrorDialog(
    BuildContext context, {
    required String title,
    required String message,
    VoidCallback? onRetry,
    VoidCallback? onCancel,
  }) {
    if (!context.mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 12),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          if (onCancel != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onCancel();
              },
              child: const Text('Cancel'),
            ),
          if (onRetry != null)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              child: const Text('Retry'),
            )
          else
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
        ],
      ),
    );
  }
}

/// Error information class
class ErrorInfo {
  final ErrorType type;
  final String code;
  final String message;
  final String userMessage;

  ErrorInfo({
    required this.type,
    required this.code,
    required this.message,
    required this.userMessage,
  });
}

/// Types of errors
enum ErrorType {
  network,
  authentication,
  database,
  storage,
  validation,
  permission,
  rateLimit,
  configuration,
  generic,
  unknown,
}

/// Extension for easier error handling
extension ErrorHandlerExtension<T> on Future<T> {
  /// Handle errors with context
  Future<T?> handleErrors({
    BuildContext? context,
    String? errorMessage,
    bool showError = true,
    T? defaultValue,
  }) {
    return ErrorHandlerService.handleAsync<T>(
      () => this,
      context: context,
      errorMessage: errorMessage,
      showError: showError,
      defaultValue: defaultValue,
    );
  }
}

/// Widget that handles errors in a consistent way
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(Object error)? errorBuilder;
  final void Function(Object error)? onError;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.errorBuilder,
    this.onError,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.errorBuilder?.call(_error!) ?? _buildDefaultError(context);
    }

    return widget.child;
  }

  Widget _buildDefaultError(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please try again or contact support if the problem persists.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _error = null;
              });
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

}