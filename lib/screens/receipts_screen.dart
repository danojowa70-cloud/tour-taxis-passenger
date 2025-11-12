import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../models/receipt.dart';
import '../providers/receipts_provider.dart';

class ReceiptsScreen extends ConsumerStatefulWidget {
  const ReceiptsScreen({super.key});

  @override
  ConsumerState<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends ConsumerState<ReceiptsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  ReceiptType? _selectedType;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      setState(() {
        switch (_tabController.index) {
          case 0:
            _selectedType = null;
            break;
          case 1:
            _selectedType = ReceiptType.instantRide;
            break;
          case 2:
            _selectedType = ReceiptType.scheduledRide;
            break;
          case 3:
            _selectedType = ReceiptType.premiumBooking;
            break;
          case 4:
            _selectedType = ReceiptType.cargoDelivery;
            break;
        }
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final receiptsAsync = ref.watch(receiptsByTypeProvider(_selectedType));
    final totalAmount = ref.watch(totalAmountByTypeProvider(_selectedType));
    final receiptCount = ref.watch(receiptCountByTypeProvider(_selectedType));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        title: const Text('Receipts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(allReceiptsProvider);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          indicatorColor: theme.colorScheme.primary,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: '🚗 Instant'),
            Tab(text: '📅 Scheduled'),
            Tab(text: '✈️ Premium'),
            Tab(text: '📦 Cargo'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Summary card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primaryContainer,
                  theme.colorScheme.secondaryContainer,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                  '📊 Total Receipts',
                  receiptCount.toString(),
                  theme,
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.3),
                ),
                _buildSummaryItem(
                  '💰 Total Amount',
                  'KSh ${totalAmount.toStringAsFixed(2)}',
                  theme,
                ),
              ],
            ),
          ),

          // Receipts list
          Expanded(
            child: receiptsAsync.when(
              data: (receipts) {
                if (receipts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long,
                          size: 80,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No receipts found',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedType == null
                              ? 'Your receipts will appear here'
                              : 'No ${_getTypeDisplayName(_selectedType!)} receipts yet',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(allReceiptsProvider);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: receipts.length,
                    itemBuilder: (context, index) {
                      final receipt = receipts[index];
                      return _buildReceiptCard(receipt, theme);
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 60,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading receipts',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        ref.invalidate(allReceiptsProvider);
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
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

  Widget _buildSummaryItem(String label, String value, ThemeData theme) {
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptCard(Receipt receipt, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showReceiptDetails(receipt),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getTypeColor(receipt.type).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      receipt.typeIcon,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          receipt.typeDisplayName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _getTypeColor(receipt.type),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          receipt.bookingId,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.download),
                    onPressed: () => _downloadReceipt(receipt),
                    tooltip: 'Download PDF',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(color: theme.dividerColor),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Date',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(receipt.dateTime),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Amount',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'KSh ${receipt.totalAmount.toStringAsFixed(2)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (receipt.pickupAddress != null || receipt.destinationAddress != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${receipt.pickupAddress ?? ""} → ${receipt.destinationAddress ?? ""}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(ReceiptType type) {
    switch (type) {
      case ReceiptType.instantRide:
        return Colors.blue;
      case ReceiptType.scheduledRide:
        return Colors.purple;
      case ReceiptType.premiumBooking:
        return Colors.indigo;
      case ReceiptType.cargoDelivery:
        return Colors.orange;
    }
  }

  String _getTypeDisplayName(ReceiptType type) {
    switch (type) {
      case ReceiptType.instantRide:
        return 'instant ride';
      case ReceiptType.scheduledRide:
        return 'scheduled ride';
      case ReceiptType.premiumBooking:
        return 'premium booking';
      case ReceiptType.cargoDelivery:
        return 'cargo delivery';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Future<void> _downloadReceipt(Receipt receipt) async {
    try {
      final service = ref.read(receiptsServiceProvider);
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final filePath = await service.generateReceiptPdfFromReceipt(receipt);
      
      if (!mounted) return;
      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Receipt downloaded to: $filePath'),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () async {
              final bytes = await service.generateReceiptBytesFromReceipt(receipt);
              await Printing.layoutPdf(
                onLayout: (format) async => bytes,
              );
            },
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to download receipt: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _showReceiptDetails(Receipt receipt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${receipt.typeIcon} Receipt Details',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildDetailRow('Booking ID', receipt.bookingId),
                  _buildDetailRow('Type', receipt.typeDisplayName),
                  _buildDetailRow('Customer', receipt.passengerName),
                  _buildDetailRow('Date', _formatDate(receipt.dateTime)),
                  _buildDetailRow('Status', receipt.status.toUpperCase()),
                  if (receipt.driverName != null)
                    _buildDetailRow('Driver', receipt.driverName!),
                  if (receipt.vehicleInfo != null)
                    _buildDetailRow('Vehicle', receipt.vehicleInfo!),
                  if (receipt.pickupAddress != null)
                    _buildDetailRow('From', receipt.pickupAddress!),
                  if (receipt.destinationAddress != null)
                    _buildDetailRow('To', receipt.destinationAddress!),
                  if (receipt.distance != null)
                    _buildDetailRow('Distance', '${receipt.distance!.toStringAsFixed(1)} km'),
                  if (receipt.duration != null)
                    _buildDetailRow('Duration', '${(receipt.duration! / 60).round()} min'),
                  if (receipt.paymentMethod != null)
                    _buildDetailRow('Payment', receipt.paymentMethod!),
                  const Divider(height: 32),
                  _buildDetailRow(
                    'Total Amount',
                    'KSh ${receipt.totalAmount.toStringAsFixed(2)}',
                    isTotal: true,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            Navigator.pop(context);
                            final service = ref.read(receiptsServiceProvider);
                            final bytes = await service.generateReceiptBytesFromReceipt(receipt);
                            await Printing.sharePdf(
                              bytes: bytes,
                              filename: 'TourTaxi_Receipt_${receipt.bookingId}.pdf',
                            );
                          },
                          icon: const Icon(Icons.share),
                          label: const Text('Share'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _downloadReceipt(receipt);
                          },
                          icon: const Icon(Icons.download),
                          label: const Text('Download PDF'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isTotal = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: isTotal ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                fontSize: isTotal ? 20 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
