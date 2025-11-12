import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/receipt.dart';
import '../services/receipts_service.dart';

// Receipts service provider
final receiptsServiceProvider = Provider<ReceiptsService>((ref) {
  return ReceiptsService(Supabase.instance.client);
});

// All receipts provider
final allReceiptsProvider = FutureProvider<List<Receipt>>((ref) async {
  final service = ref.watch(receiptsServiceProvider);
  return await service.fetchAllReceipts();
});

// Receipts by type provider
final receiptsByTypeProvider = FutureProvider.family<List<Receipt>, ReceiptType?>((ref, type) async {
  final allReceipts = await ref.watch(allReceiptsProvider.future);
  
  if (type == null) {
    return allReceipts;
  }
  
  return allReceipts.where((r) => r.type == type).toList();
});

// Receipt count by type
final receiptCountByTypeProvider = Provider.family<int, ReceiptType?>((ref, type) {
  final receiptsAsync = type == null 
      ? ref.watch(allReceiptsProvider)
      : ref.watch(receiptsByTypeProvider(type));
  
  return receiptsAsync.maybeWhen(
    data: (receipts) => receipts.length,
    orElse: () => 0,
  );
});

// Total amount by type
final totalAmountByTypeProvider = Provider.family<double, ReceiptType?>((ref, type) {
  final receiptsAsync = type == null 
      ? ref.watch(allReceiptsProvider)
      : ref.watch(receiptsByTypeProvider(type));
  
  return receiptsAsync.maybeWhen(
    data: (receipts) => receipts.fold(0.0, (sum, receipt) => sum + receipt.totalAmount),
    orElse: () => 0.0,
  );
});
