import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/receipt.dart';

class ReceiptData {
  final String rideId;
  final String passengerName;
  final String driverName;
  final String vehicleInfo;
  final String pickupAddress;
  final String destinationAddress;
  final DateTime rideDate;
  final double distance;
  final double duration;
  final double baseFare;
  final double serviceFee;
  final double totalAmount;
  final String paymentMethod;
  final String status;

  const ReceiptData({
    required this.rideId,
    required this.passengerName,
    required this.driverName,
    required this.vehicleInfo,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.rideDate,
    required this.distance,
    required this.duration,
    required this.baseFare,
    required this.serviceFee,
    required this.totalAmount,
    required this.paymentMethod,
    required this.status,
  });
}

class ReceiptsService {
  final SupabaseClient _client;

  ReceiptsService(this._client);

  /// Fetch all receipts for the current user
  Future<List<Receipt>> fetchAllReceipts() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');
      
      if (kDebugMode) {
        debugPrint('==========================================');
        debugPrint('🔍 FETCHING RECEIPTS FOR USER: $userId');
        debugPrint('==========================================');
      }

      final receipts = <Receipt>[];

      // Fetch instant rides - Fetch ALL rides then filter by current user's passenger records
      try {
        if (kDebugMode) {
          debugPrint('🔍 Fetching ALL instant rides from database...');
        }
        
        // Get ALL completed/cancelled rides (no filter yet)
        final allRides = await _client
            .from('rides')
            .select()
            .inFilter('status', ['completed', 'cancelled']);
        
        if (kDebugMode) {
          debugPrint('📋 Found ${allRides.length} total completed/cancelled rides in database');
          if (allRides.isNotEmpty) {
            debugPrint('📦 Sample ride data: ${allRides.first}');
            debugPrint('🔑 Keys in ride: ${allRides.first.keys.toList()}');
          }
        }
        
        // Get passenger records for current user
        final passengerRecords = await _client
            .from('passengers')
            .select('id')
            .eq('auth_user_id', userId);
        
        final passengerIds = passengerRecords.map((p) => p['id'] as String).toList();
        passengerIds.add(userId); // Also include auth user ID directly
        
        if (kDebugMode) {
          debugPrint('👥 Passenger IDs to match: $passengerIds');
        }
        
        // Filter rides for current user
        final userRides = allRides.where((ride) {
          final ridePassengerId = ride['passenger_id']?.toString();
          return ridePassengerId != null && passengerIds.contains(ridePassengerId);
        }).toList();
        
        if (kDebugMode) {
          debugPrint('✅ Filtered to ${userRides.length} rides for current user');
        }
        
        receipts.addAll(userRides.map((r) => Receipt.fromInstantRide(r)));
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ Error fetching instant rides: $e');
        }
      }

      // Fetch scheduled rides - Fetch ALL then filter
      try {
        if (kDebugMode) {
          debugPrint('🔍 Fetching ALL scheduled rides...');
        }
        
        // Get ALL scheduled rides
        final allScheduledRides = await _client
            .from('scheduled_rides')
            .select();
        
        if (kDebugMode) {
          debugPrint('📋 Found ${allScheduledRides.length} total scheduled rides');
          if (allScheduledRides.isNotEmpty) {
            debugPrint('🔑 Keys in scheduled_ride: ${allScheduledRides.first.keys.toList()}');
          }
        }
        
        // Get passenger records for current user
        final passengerRecords = await _client
            .from('passengers')
            .select('id')
            .eq('auth_user_id', userId);
        
        final passengerIds = passengerRecords.map((p) => p['id'] as String).toList();
        passengerIds.add(userId); // Also include auth user ID directly
        
        // Filter scheduled rides - check multiple possible column names
        final userScheduledRides = allScheduledRides.where((ride) {
          final rideUserId = ride['user_id']?.toString();
          final ridePassengerId = ride['passenger_id']?.toString();
          
          return (rideUserId != null && passengerIds.contains(rideUserId)) ||
                 (ridePassengerId != null && passengerIds.contains(ridePassengerId));
        }).toList();
        
        // Filter by valid status
        final validScheduledRides = userScheduledRides.where((ride) {
          final status = ride['status']?.toString().toLowerCase();
          return status != null && ['pending', 'confirmed', 'assigned', 'in_progress', 'completed', 'cancelled'].contains(status);
        }).toList();
        
        if (kDebugMode) {
          debugPrint('✅ Filtered to ${validScheduledRides.length} scheduled rides for current user');
        }
        
        receipts.addAll(validScheduledRides.map((r) => Receipt.fromScheduledRide(r)));
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ Error fetching scheduled rides: $e');
        }
      }

      // Fetch premium bookings
      try {
        final premiumBookings = await _client
            .from('boarding_passes')
            .select()
            .eq('user_id', userId)
            .inFilter('status', ['completed', 'cancelled']);
        receipts.addAll(premiumBookings.map((r) => Receipt.fromPremiumBooking(r)));
        if (kDebugMode) {
          debugPrint('✅ Fetched ${premiumBookings.length} premium bookings');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ Error fetching premium bookings: $e');
        }
      }

      // Fetch cargo deliveries (try view first, then fall back to cargo_requests)
      try {
        List<dynamic> cargoData = [];
        
        // Try fetching from cargo_deliveries view first
        try {
          cargoData = await _client
              .from('cargo_deliveries')
              .select()
              .eq('user_id', userId);
          
          // Filter valid cargo deliveries
          final validCargo = cargoData.where((cargo) {
            final status = cargo['status']?.toString().toLowerCase();
            return status != null && ['confirmed', 'pickedup', 'intransit', 'outfordelivery', 'delivered', 'cancelled'].contains(status.replaceAll('_', ''));
          }).toList();
          
          if (kDebugMode) {
            debugPrint('✅ Fetched ${validCargo.length} cargo deliveries from view (from ${cargoData.length} total)');
          }
          cargoData = validCargo;
        } catch (viewError) {
          if (kDebugMode) {
            debugPrint('⚠️ View not available, fetching from cargo_requests: $viewError');
          }
          
          // Fallback to cargo_requests table
          try {
            cargoData = await _client
                .from('cargo_requests')
                .select()
                .eq('user_id', userId);
            
            // Filter by accepted status or other valid statuses
            final validRequests = cargoData.where((request) {
              final status = request['status']?.toString().toLowerCase();
              return status != null && ['accepted', 'in_progress', 'completed', 'delivered'].contains(status);
            }).toList();
            
            if (kDebugMode) {
              debugPrint('✅ Fetched ${validRequests.length} cargo requests (from ${cargoData.length} total)');
            }
            cargoData = validRequests;
          } catch (requestError) {
            if (kDebugMode) {
              debugPrint('❌ Failed to fetch cargo_requests: $requestError');
            }
            cargoData = [];
          }
        }
        
        if (cargoData.isNotEmpty) {
          final cargoReceipts = cargoData.map((r) {
            try {
              return Receipt.fromCargoDelivery(r);
            } catch (e) {
              if (kDebugMode) {
                debugPrint('⚠️ Failed to parse cargo delivery: $e');
                debugPrint('Data: $r');
              }
              return null;
            }
          }).whereType<Receipt>().toList();
          
          receipts.addAll(cargoReceipts);
          if (kDebugMode) {
            debugPrint('✅ Successfully parsed ${cargoReceipts.length} cargo receipts');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ Error fetching cargo deliveries: $e');
        }
      }

      // Sort by date descending
      receipts.sort((a, b) => b.dateTime.compareTo(a.dateTime));

      if (kDebugMode) {
        debugPrint('📊 Total receipts fetched: ${receipts.length}');
      }
      return receipts;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to fetch receipts: $e');
      }
      throw Exception('Failed to fetch receipts: $e');
    }
  }

  /// Fetch receipts by type
  Future<List<Receipt>> fetchReceiptsByType(ReceiptType type) async {
    final allReceipts = await fetchAllReceipts();
    return allReceipts.where((r) => r.type == type).toList();
  }

  /// Generate PDF receipt for any receipt type
  Future<String> generateReceiptPdfFromReceipt(Receipt receipt) async {
    try {
      final pdf = await _createPdfFromReceipt(receipt);
      final filePath = await _savePdfToDevice(pdf, receipt.bookingId);
      return filePath;
    } catch (e) {
      throw Exception('Failed to generate receipt: $e');
    }
  }

  /// Generate PDF bytes for sharing
  Future<Uint8List> generateReceiptBytesFromReceipt(Receipt receipt) async {
    try {
      final pdf = await _createPdfFromReceipt(receipt);
      return await pdf.save();
    } catch (e) {
      throw Exception('Failed to generate receipt bytes: $e');
    }
  }

  /// Generate a PDF receipt and save to device storage
  Future<String> generateReceiptPdf({required String rideId, required double amount}) async {
    try {
      // Fetch ride details from database
      final receiptData = await _fetchReceiptData(rideId, amount);
      
      // Generate PDF
      final pdf = await _createPdfDocument(receiptData);
      
      // Save to device
      final filePath = await _savePdfToDevice(pdf, rideId);
      
      return filePath;
    } catch (e) {
      throw Exception('Failed to generate receipt: $e');
    }
  }

  /// Generate PDF as bytes for sharing or printing
  Future<Uint8List> generateReceiptBytes({required String rideId, required double amount}) async {
    try {
      final receiptData = await _fetchReceiptData(rideId, amount);
      final pdf = await _createPdfDocument(receiptData);
      return await pdf.save();
    } catch (e) {
      throw Exception('Failed to generate receipt bytes: $e');
    }
  }

  /// Print receipt directly
  Future<void> printReceipt({required String rideId, required double amount}) async {
    try {
      final pdfBytes = await generateReceiptBytes(rideId: rideId, amount: amount);
      await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
    } catch (e) {
      throw Exception('Failed to print receipt: $e');
    }
  }

  /// Share receipt via platform share dialog
  Future<void> shareReceipt({required String rideId, required double amount}) async {
    try {
      final pdfBytes = await generateReceiptBytes(rideId: rideId, amount: amount);
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'TourTaxi_Receipt_$rideId.pdf',
      );
    } catch (e) {
      throw Exception('Failed to share receipt: $e');
    }
  }

  Future<ReceiptData> _fetchReceiptData(String rideId, double amount) async {
    // Fetch ride details from Supabase
    final rideResponse = await _client
        .from('rides')
        .select('*, passengers(*), drivers(*)')
        .eq('id', rideId)
        .single();

    // Parse the response
    final passenger = rideResponse['passengers'] as Map<String, dynamic>?;
    final driver = rideResponse['drivers'] as Map<String, dynamic>?;
    
    return ReceiptData(
      rideId: rideId,
      passengerName: passenger?['name'] ?? rideResponse['passenger_name'] ?? 'Unknown',
      driverName: driver?['name'] ?? 'Unknown Driver',
      vehicleInfo: '${driver?['vehicle_type'] ?? ''} ${driver?['vehicle_model'] ?? ''} - ${driver?['vehicle_plate'] ?? ''}',
      pickupAddress: rideResponse['pickup_address'] ?? 'Unknown',
      destinationAddress: rideResponse['destination_address'] ?? 'Unknown',
      rideDate: DateTime.parse(rideResponse['created_at']),
      distance: (rideResponse['distance'] as num?)?.toDouble() ?? 0.0,
      duration: (rideResponse['duration'] as num?)?.toDouble() ?? 0.0,
      baseFare: amount * 0.9, // 90% base fare
      serviceFee: amount * 0.1, // 10% service fee
      totalAmount: amount,
      paymentMethod: rideResponse['payment_method'] ?? 'Cash',
      status: rideResponse['status'] ?? 'Unknown',
    );
  }

  Future<pw.Document> _createPdfFromReceipt(Receipt receipt) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'TOURTAXI',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '${receipt.typeIcon} ${receipt.typeDisplayName.toUpperCase()} RECEIPT',
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 30),
              
              // Receipt Details
              pw.Text(
                'Receipt #${receipt.bookingId}',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              
              pw.SizedBox(height: 20),
              
              // Customer & Booking Information
              _buildInfoSection('Booking Information', [
                ['Date:', _formatDateTime(receipt.dateTime)],
                ['Customer:', receipt.passengerName],
                ['Booking Type:', receipt.typeDisplayName],
                if (receipt.driverName != null) ['Driver:', receipt.driverName!],
                if (receipt.vehicleInfo != null) ['Vehicle:', receipt.vehicleInfo!],
                ['Status:', receipt.status.toUpperCase()],
              ]),
              
              pw.SizedBox(height: 20),
              
              // Route/Trip Information
              if (receipt.pickupAddress != null || receipt.destinationAddress != null)
                _buildInfoSection('Trip Information', [
                  if (receipt.pickupAddress != null) ['From:', receipt.pickupAddress!],
                  if (receipt.destinationAddress != null) ['To:', receipt.destinationAddress!],
                  if (receipt.distance != null) ['Distance:', '${receipt.distance!.toStringAsFixed(1)} km'],
                  if (receipt.duration != null) ['Duration:', '${(receipt.duration! / 60).round()} min'],
                ]),
              
              if (receipt.pickupAddress != null || receipt.destinationAddress != null)
                pw.SizedBox(height: 20),
              
              // Additional Details (for Premium and Cargo)
              if (receipt.additionalDetails != null && receipt.additionalDetails!.isNotEmpty)
                _buildAdditionalDetails(receipt),
              
              if (receipt.additionalDetails != null && receipt.additionalDetails!.isNotEmpty)
                pw.SizedBox(height: 20),
              
              // Payment Information
              _buildInfoSection('Payment Information', [
                ['Amount:', 'KSh ${receipt.totalAmount.toStringAsFixed(2)}'],
                if (receipt.paymentMethod != null) ['Payment Method:', receipt.paymentMethod!],
              ]),
              
              pw.SizedBox(height: 10),
              
              // Total
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'TOTAL AMOUNT',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'KSh ${receipt.totalAmount.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue,
                      ),
                    ),
                  ],
                ),
              ),
              
              pw.Spacer(),
              
              // Footer
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Thank you for choosing TourTaxi!',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'For support, contact us at support@tourtaxi.com',
                      style: const pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
    
    return pdf;
  }

  pw.Widget _buildAdditionalDetails(Receipt receipt) {
    final details = receipt.additionalDetails!;
    final items = <List<String>>[];
    
    if (receipt.type == ReceiptType.premiumBooking) {
      if (details['operator_name'] != null) {
        items.add(['Operator:', details['operator_name']]);
      }
      if (details['seat_number'] != null) {
        items.add(['Seat:', details['seat_number']]);
      }
      if (details['gate'] != null) {
        items.add(['Gate:', details['gate']]);
      }
    } else if (receipt.type == ReceiptType.cargoDelivery) {
      if (details['package_description'] != null) {
        items.add(['Package:', details['package_description']]);
      }
      if (details['package_type'] != null) {
        items.add(['Package Type:', details['package_type']]);
      }
      if (details['weight'] != null) {
        items.add(['Weight:', '${details['weight']} kg']);
      }
      if (details['priority'] != null) {
        items.add(['Priority:', details['priority'].toString().toUpperCase()]);
      }
      if (details['recipient_name'] != null) {
        items.add(['Recipient:', details['recipient_name']]);
      }
      if (details['recipient_phone'] != null) {
        items.add(['Recipient Phone:', details['recipient_phone']]);
      }
    }
    
    if (items.isEmpty) return pw.SizedBox();
    
    return _buildInfoSection('Additional Details', items);
  }

  Future<pw.Document> _createPdfDocument(ReceiptData data) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'TOURTAXI',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'RIDE RECEIPT',
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 30),
              
              // Receipt Details
              pw.Text(
                'Receipt #${data.rideId}',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              
              pw.SizedBox(height: 20),
              
              // Trip Information
              _buildInfoSection('Trip Information', [
                ['Date:', _formatDateTime(data.rideDate)],
                ['Passenger:', data.passengerName],
                ['Driver:', data.driverName],
                ['Vehicle:', data.vehicleInfo],
                ['Status:', data.status.toUpperCase()],
              ]),
              
              pw.SizedBox(height: 20),
              
              // Route Information
              _buildInfoSection('Route Information', [
                ['From:', data.pickupAddress],
                ['To:', data.destinationAddress],
                ['Distance:', '${data.distance.toStringAsFixed(1)} km'],
                ['Duration:', '${(data.duration / 60).round()} min'],
              ]),
              
              pw.SizedBox(height: 20),
              
              // Payment Information
              _buildInfoSection('Payment Information', [
                ['Base Fare:', 'KSh ${data.baseFare.toStringAsFixed(2)}'],
                ['Service Fee:', 'KSh ${data.serviceFee.toStringAsFixed(2)}'],
                ['Payment Method:', data.paymentMethod],
              ]),
              
              pw.SizedBox(height: 10),
              
              // Total
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'TOTAL AMOUNT',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'KSh ${data.totalAmount.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue,
                      ),
                    ),
                  ],
                ),
              ),
              
              pw.Spacer(),
              
              // Footer
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Thank you for choosing TourTaxi!',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'For support, contact us at support@tourtaxi.com',
                      style: const pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
    
    return pdf;
  }

  pw.Widget _buildInfoSection(String title, List<List<String>> items) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue,
          ),
        ),
        pw.SizedBox(height: 8),
        ...items.map((item) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(item[0], style: const pw.TextStyle(fontSize: 12)),
              pw.Text(
                item[1],
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<String> _savePdfToDevice(pw.Document pdf, String rideId) async {
    final output = await getApplicationDocumentsDirectory();
    final file = File('${output.path}/TourTaxi_Receipt_$rideId.pdf');
    await file.writeAsBytes(await pdf.save());
    return file.path;
  }
}


