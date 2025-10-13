import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      vehicleInfo: '${driver?['vehicle_make'] ?? ''} ${driver?['vehicle_model'] ?? ''} - ${driver?['vehicle_plate'] ?? ''}',
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


