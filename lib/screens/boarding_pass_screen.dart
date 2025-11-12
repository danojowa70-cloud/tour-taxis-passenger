import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
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
          // Only show cancel button for active bookings
          if (boardingPass.isActive) ...[
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
            
            const SizedBox(height: 12),
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
      case BoardingPassStatus.confirmed:
        return Colors.indigo;
      case BoardingPassStatus.checkedIn:
        return Colors.teal;
      case BoardingPassStatus.boarding:
        return Colors.orange;
      case BoardingPassStatus.departed:
        return Colors.purple;
      case BoardingPassStatus.arrived:
        return Colors.cyan;
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

  Future<void> _downloadPass(BuildContext context, BoardingPass boardingPass) async {
    try {
      // Generate PDF
      final pdf = pw.Document();
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue,
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'BOARDING PASS',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          boardingPass.origin ?? 'N/A',
                          style: pw.TextStyle(
                            fontSize: 32,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                        pw.Icon(const pw.IconData(0xe530), color: PdfColors.white),
                        pw.Text(
                          boardingPass.destination,
                          style: pw.TextStyle(
                            fontSize: 32,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 30),
              
              // Details
              pw.Row(
                children: [
                  pw.Expanded(
                    child: _buildPdfDetailItem('PASSENGER', boardingPass.passengerName),
                  ),
                  pw.Expanded(
                    child: _buildPdfDetailItem('BOOKING ID', boardingPass.bookingId),
                  ),
                ],
              ),
              
              pw.SizedBox(height: 20),
              
              pw.Row(
                children: [
                  pw.Expanded(
                    child: _buildPdfDetailItem('DEPARTURE', _formatDateTime(boardingPass.departureTime)),
                  ),
                  if (boardingPass.arrivalTime != null)
                    pw.Expanded(
                      child: _buildPdfDetailItem('ARRIVAL', _formatDateTime(boardingPass.arrivalTime!)),
                    ),
                ],
              ),
              
              pw.SizedBox(height: 20),
              
              pw.Row(
                children: [
                  if (boardingPass.seatNumber != null)
                    pw.Expanded(
                      child: _buildPdfDetailItem('SEAT', boardingPass.seatNumber!),
                    ),
                  if (boardingPass.gate != null)
                    pw.Expanded(
                      child: _buildPdfDetailItem('GATE', boardingPass.gate!),
                    ),
                  pw.Expanded(
                    child: _buildPdfDetailItem('STATUS', boardingPass.statusDisplayName),
                  ),
                ],
              ),
              
              pw.SizedBox(height: 30),
              
              // QR Code
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'SCAN FOR BOARDING',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.BarcodeWidget(
                      data: boardingPass.qrCode,
                      barcode: pw.Barcode.qrCode(),
                      width: 150,
                      height: 150,
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      boardingPass.qrCode,
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
              
              pw.Spacer(),
              
              // Footer
              pw.Center(
                child: pw.Text(
                  'Thank you for choosing TourTaxi',
                  style: const pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      
      // Save to device
      final output = await getApplicationDocumentsDirectory();
      final file = File('${output.path}/boarding_pass_${boardingPass.bookingId}.pdf');
      await file.writeAsBytes(await pdf.save());
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Boarding pass saved to ${file.path}'),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () async {
                await Printing.sharePdf(
                  bytes: await pdf.save(),
                  filename: 'boarding_pass_${boardingPass.bookingId}.pdf',
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download: $e')),
        );
      }
    }
  }
  
  pw.Widget _buildPdfDetailItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 10,
            color: PdfColors.grey600,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Future<void> _addToWallet(BuildContext context, BoardingPass boardingPass) async {
    try {
      // For Android: Try to use Google Wallet
      if (Platform.isAndroid) {
        // Create a pass data URL for Google Wallet
        // In production, you would generate a proper JWT token from your backend
        // and use Google Wallet API
        
        
        // Try to open Google Wallet or show alternative
        final walletUrl = Uri.parse('https://pay.google.com/gp/v/save');
        
        if (await canLaunchUrl(walletUrl)) {
          // In production, this would use proper Google Wallet API
          // For now, show instructions
          if (context.mounted) {
            _showWalletInstructions(context, boardingPass);
          }
        } else {
          throw 'Google Wallet not available';
        }
      } else if (Platform.isIOS) {
        // For iOS: Use Apple Wallet (.pkpass file)
        if (context.mounted) {
          _showWalletInstructions(context, boardingPass);
        }
      } else {
        throw 'Wallet not supported on this platform';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Wallet feature: $e')),
        );
      }
    }
  }
  
  void _showWalletInstructions(BuildContext context, BoardingPass boardingPass) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add to Wallet'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your boarding pass can be added to your mobile wallet:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              if (Platform.isAndroid) ...[
                const Text('📱 For Google Wallet:'),
                const SizedBox(height: 8),
                const Text(
                  '1. Take a screenshot of your boarding pass\n'
                  '2. Open Google Wallet app\n'
                  '3. Tap "Add to Wallet"\n'
                  '4. Select "Photo" and choose the screenshot',
                  style: TextStyle(fontSize: 13),
                ),
              ] else if (Platform.isIOS) ...[
                const Text('📱 For Apple Wallet:'),
                const SizedBox(height: 8),
                const Text(
                  '1. Download your boarding pass PDF\n'
                  '2. Look for "Add to Apple Wallet" option\n'
                  '3. Follow the prompts to add',
                  style: TextStyle(fontSize: 13),
                ),
              ],
              
              const SizedBox(height: 16),
              
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Keep your QR code accessible for easy boarding',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              Text(
                'Booking ID: ${boardingPass.bookingId}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _downloadPass(context, boardingPass);
            },
            icon: const Icon(Icons.download),
            label: const Text('Download PDF'),
          ),
        ],
      ),
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