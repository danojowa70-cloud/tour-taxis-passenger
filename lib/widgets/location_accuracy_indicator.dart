import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/precision_location_service.dart';

/// Widget that displays current location accuracy status
class LocationAccuracyIndicator extends StatelessWidget {
  final CustomLocationAccuracyStatus accuracyStatus;
  final double? accuracy;
  final bool showDetails;
  final EdgeInsetsGeometry? padding;

  const LocationAccuracyIndicator({
    super.key,
    required this.accuracyStatus,
    this.accuracy,
    this.showDetails = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _getBackgroundColor(theme),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _getBorderColor(theme),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status icon
          Icon(
            _getStatusIcon(),
            color: _getStatusColor(theme),
            size: 16,
          ),
          if (showDetails) ...[
            const SizedBox(width: 6),
            // Status text
            Text(
              _getStatusText(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: _getStatusColor(theme),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getBackgroundColor(ThemeData theme) {
    switch (accuracyStatus) {
      case CustomLocationAccuracyStatus.excellent:
        return Colors.green.withValues(alpha: 0.1);
      case CustomLocationAccuracyStatus.good:
        return Colors.blue.withValues(alpha: 0.1);
      case CustomLocationAccuracyStatus.fair:
        return Colors.orange.withValues(alpha: 0.1);
      case CustomLocationAccuracyStatus.poor:
        return Colors.red.withValues(alpha: 0.1);
      case CustomLocationAccuracyStatus.stale:
        return Colors.grey.withValues(alpha: 0.1);
      case CustomLocationAccuracyStatus.unknown:
        return theme.colorScheme.surface;
    }
  }

  Color _getBorderColor(ThemeData theme) {
    switch (accuracyStatus) {
      case CustomLocationAccuracyStatus.excellent:
        return Colors.green.withValues(alpha: 0.3);
      case CustomLocationAccuracyStatus.good:
        return Colors.blue.withValues(alpha: 0.3);
      case CustomLocationAccuracyStatus.fair:
        return Colors.orange.withValues(alpha: 0.3);
      case CustomLocationAccuracyStatus.poor:
        return Colors.red.withValues(alpha: 0.3);
      case CustomLocationAccuracyStatus.stale:
        return Colors.grey.withValues(alpha: 0.3);
      case CustomLocationAccuracyStatus.unknown:
        return theme.colorScheme.outline.withValues(alpha: 0.3);
    }
  }

  Color _getStatusColor(ThemeData theme) {
    switch (accuracyStatus) {
      case CustomLocationAccuracyStatus.excellent:
        return Colors.green.shade700;
      case CustomLocationAccuracyStatus.good:
        return Colors.blue.shade700;
      case CustomLocationAccuracyStatus.fair:
        return Colors.orange.shade700;
      case CustomLocationAccuracyStatus.poor:
        return Colors.red.shade700;
      case CustomLocationAccuracyStatus.stale:
        return Colors.grey.shade700;
      case CustomLocationAccuracyStatus.unknown:
        return theme.colorScheme.onSurface.withValues(alpha: 0.6);
    }
  }

  IconData _getStatusIcon() {
    switch (accuracyStatus) {
      case CustomLocationAccuracyStatus.excellent:
        return Icons.gps_fixed;
      case CustomLocationAccuracyStatus.good:
        return Icons.gps_fixed;
      case CustomLocationAccuracyStatus.fair:
        return Icons.gps_not_fixed;
      case CustomLocationAccuracyStatus.poor:
        return Icons.gps_not_fixed;
      case CustomLocationAccuracyStatus.stale:
        return Icons.gps_off;
      case CustomLocationAccuracyStatus.unknown:
        return Icons.location_disabled;
    }
  }

  String _getStatusText() {
    final accuracyText = accuracy != null 
        ? ' (±${accuracy!.toStringAsFixed(1)}m)'
        : '';
    
    switch (accuracyStatus) {
      case CustomLocationAccuracyStatus.excellent:
        return 'High Precision$accuracyText';
      case CustomLocationAccuracyStatus.good:
        return 'Good GPS$accuracyText';
      case CustomLocationAccuracyStatus.fair:
        return 'Fair GPS$accuracyText';
      case CustomLocationAccuracyStatus.poor:
        return 'Poor GPS$accuracyText';
      case CustomLocationAccuracyStatus.stale:
        return 'GPS Stale';
      case CustomLocationAccuracyStatus.unknown:
        return 'GPS Off';
    }
  }
}

/// Stream-based location accuracy indicator that updates automatically
class StreamLocationAccuracyIndicator extends StatelessWidget {
  final PrecisionLocationService locationService;
  final bool showDetails;
  final EdgeInsetsGeometry? padding;

  const StreamLocationAccuracyIndicator({
    super.key,
    required this.locationService,
    this.showDetails = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Position>(
      stream: locationService.locationStream,
      builder: (context, snapshot) {
        final accuracyStatus = locationService.getAccuracyStatus();
        final accuracy = locationService.lastKnownPosition?.accuracy;
        
        return LocationAccuracyIndicator(
          accuracyStatus: accuracyStatus,
          accuracy: accuracy,
          showDetails: showDetails,
          padding: padding,
        );
      },
    );
  }
}