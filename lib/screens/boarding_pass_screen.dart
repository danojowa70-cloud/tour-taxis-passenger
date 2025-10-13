import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../models/boarding_pass.dart';
import '../providers/boarding_pass_providers.dart';

class BoardingPassScreen extends ConsumerWidget {
  final String boardingPassId;

  const BoardingPassScreen({super.key, required this.boardingPassId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardingPass = ref.watch(boardingPassByIdProvider(boardingPassId));
    final theme = Theme.of(context);

    if (boardingPass == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Boarding Pass'),
        ),
        body: const Center(
          child: Text('Boarding pass not found'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Boarding Pass'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareboardingPass(context, boardingPass),
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'save',
                child: Row(
                  children: [
                    Icon(Icons.save_alt),
                    SizedBox(width: 8),
                    Text('Save to Photos'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'copy',
                child: Row(
                  children: [
                    Icon(Icons.copy),
                    SizedBox(width: 8),
                    Text('Copy Booking ID'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              switch (value) {
                case 'save':
                  _saveBoardingPass(context, boardingPass);
                  break;
                case 'copy':
                  _copyBookingId(context, boardingPass);
                  break;
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            // Main boarding pass card
            _buildBoardingPassCard(context, theme, boardingPass),
            
            const SizedBox(height: 24),
            
            // Action buttons
            _buildActionButtons(context, theme, boardingPass, ref),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBoardingPassCard(BuildContext context, ThemeData theme, BoardingPass boardingPass) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header section
          _buildPassHeader(theme, boardingPass),
          
          // Perforated line
          _buildPerforatedLine(theme),
          
          // Details section
          _buildPassDetails(theme, boardingPass),
          
          // QR Code section
          _buildQRCodeSection(theme, boardingPass),
        ],
      ),
    );
  }

  Widget _buildPassHeader(ThemeData theme, BoardingPass boardingPass) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getStatusColor(boardingPass.status),
            _getStatusColor(boardingPass.status).withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    boardingPass.vehicleTypeDisplayName.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    boardingPass.operatorName,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Text(
                boardingPass.vehicleType.emoji,
                style: const TextStyle(fontSize: 32),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Route information
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FROM',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      boardingPass.origin?.toUpperCase() ?? 'N/A',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.flight_takeoff,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'TO',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      boardingPass.destination.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPerforatedLine(ThemeData theme) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: CustomPaint(
        painter: DashedLinePainter(),
        size: const Size(double.infinity, 1),
      ),
    );
  }

  Widget _buildPassDetails(ThemeData theme, BoardingPass boardingPass) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Passenger and booking info
          Row(
            children: [
              Expanded(
                child: _DetailItem(
                  label: 'PASSENGER',
                  value: boardingPass.passengerName.toUpperCase(),
                ),
              ),
              Expanded(
                child: _DetailItem(
                  label: 'BOOKING ID',
                  value: boardingPass.bookingId,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Date and time info
          Row(
            children: [
              Expanded(
                child: _DetailItem(
                  label: 'DEPARTURE',
                  value: _formatDateTime(boardingPass.departureTime),
                ),
              ),
              if (boardingPass.arrivalTime != null)
                Expanded(
                  child: _DetailItem(
                    label: 'ARRIVAL',
                    value: _formatDateTime(boardingPass.arrivalTime!),
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Additional details
          Row(
            children: [
              if (boardingPass.seatNumber != null)
                Expanded(
                  child: _DetailItem(
                    label: 'SEAT',
                    value: boardingPass.seatNumber!,
                  ),
                ),
              if (boardingPass.gate != null)
                Expanded(
                  child: _DetailItem(
                    label: 'GATE',
                    value: boardingPass.gate!,
                  ),
                ),
              Expanded(
                child: _DetailItem(
                  label: 'STATUS',
                  value: boardingPass.statusDisplayName.toUpperCase(),
                  valueColor: _getStatusColor(boardingPass.status),
                ),
              ),
            ],
          ),
          
          if (boardingPass.terminal != null) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _DetailItem(
                    label: 'TERMINAL',
                    value: boardingPass.terminal!,
                  ),
                ),
                if (boardingPass.fare != null)
                  Expanded(
                    child: _DetailItem(
                      label: 'FARE',
                      value: 'KSh ${boardingPass.fare!.toStringAsFixed(0)}',
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQRCodeSection(ThemeData theme, BoardingPass boardingPass) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Text(
            'SCAN FOR BOARDING',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // QR Code placeholder
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.qr_code,
                    size: 80,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'QR CODE',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          Text(
            boardingPass.qrCode,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, ThemeData theme, BoardingPass boardingPass, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          if (boardingPass.isActive) ...[
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => _checkInForBoarding(context, boardingPass, ref),
                icon: const Icon(Icons.flight_takeoff),
                label: const Text('Check In'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () => _cancelBoarding(context, boardingPass, ref),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancel Booking'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  side: BorderSide(color: theme.colorScheme.error),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _downloadPass(context, boardingPass),
                  icon: const Icon(Icons.download),
                  label: const Text('Download'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _addToWallet(context, boardingPass),
                  icon: const Icon(Icons.account_balance_wallet),
                  label: const Text('Add to Wallet'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.secondaryContainer,
                    foregroundColor: theme.colorScheme.onSecondaryContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper methods
  Color _getStatusColor(BoardingPassStatus status) {
    switch (status) {
      case BoardingPassStatus.upcoming:
        return Colors.blue;
      case BoardingPassStatus.boarding:
        return Colors.orange;
      case BoardingPassStatus.departed:
        return Colors.green;
      case BoardingPassStatus.completed:
        return Colors.green;
      case BoardingPassStatus.cancelled:
        return Colors.red;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    String dateStr;
    if (targetDate == today) {
      dateStr = 'Today';
    } else if (targetDate == today.add(const Duration(days: 1))) {
      dateStr = 'Tomorrow';
    } else if (targetDate == today.subtract(const Duration(days: 1))) {
      dateStr = 'Yesterday';
    } else {
      dateStr = '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
    
    final timeStr = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    return '$dateStr $timeStr';
  }

  // Action methods
  void _shareboardingPass(BuildContext context, BoardingPass boardingPass) {
    // In a real app, use share_plus package with boarding pass details
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sharing feature would be implemented here')),
    );
  }

  void _saveBoardingPass(BuildContext context, BoardingPass boardingPass) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Save to photos feature would be implemented here')),
    );
  }

  void _copyBookingId(BuildContext context, BoardingPass boardingPass) {
    Clipboard.setData(ClipboardData(text: boardingPass.bookingId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Booking ID copied to clipboard')),
    );
  }

  Future<void> _checkInForBoarding(BuildContext context, BoardingPass boardingPass, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Check In'),
        content: const Text('Are you ready to check in for your flight?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Check In'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(boardingPassProvider.notifier)
          .updateBoardingPassStatus(boardingPass.id, BoardingPassStatus.boarding);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully checked in!')),
        );
      }
    }
  }

  Future<void> _cancelBoarding(BuildContext context, BoardingPass boardingPass, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: const Text('Are you sure you want to cancel this booking? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Booking'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel Booking'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(boardingPassProvider.notifier)
          .updateBoardingPassStatus(boardingPass.id, BoardingPassStatus.cancelled);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking cancelled')),
        );
      }
    }
  }

  void _downloadPass(BuildContext context, BoardingPass boardingPass) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Download feature would be implemented here')),
    );
  }

  void _addToWallet(BuildContext context, BoardingPass boardingPass) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add to wallet feature would be implemented here')),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailItem({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor ?? theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.5)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const dashWidth = 5.0;
    const dashSpace = 3.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(math.min(startX + dashWidth, size.width), 0),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}