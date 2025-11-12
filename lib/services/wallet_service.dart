import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

class WalletService {
  final _supabase = Supabase.instance.client;

  // Get current balance from database
  Future<double> getBalance() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 0;

      final response = await _supabase
          .from('wallets')
          .select('balance')
          .eq('user_id', userId)
          .maybeSingle();

      return response?['balance']?.toDouble() ?? 0;
    } catch (e) {
      debugPrint('Error getting balance: $e');
      return 0;
    }
  }

  // Get transaction ledger from database
  Future<List<Map<String, dynamic>>> getLedger() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      // First get wallet ID
      final walletResponse = await _supabase
          .from('wallets')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      if (walletResponse == null) return [];

      final walletId = walletResponse['id'];

      // Get transactions
      final transactions = await _supabase
          .from('wallet_transactions')
          .select('*')
          .eq('wallet_id', walletId)
          .order('created_at', ascending: false);

      return (transactions as List).map((t) => {
        'type': t['type'],
        'amount': t['amount'],
        'at': t['created_at'],
        'description': t['description'],
      }).toList();
    } catch (e) {
      debugPrint('Error getting ledger: $e');
      return [];
    }
  }

  // Top up wallet
  Future<void> topUp(double amount) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      // Update wallet balance
      final walletId = await _supabase.rpc('update_wallet_balance', params: {
        'p_user_id': userId,
        'p_amount': amount,
      });

      // Log transaction
      await _supabase.from('wallet_transactions').insert({
        'wallet_id': walletId,
        'type': 'credit',
        'amount': amount,
        'description': 'Wallet top-up',
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ Wallet topped up: +$amount');
    } catch (e) {
      debugPrint('❌ Error topping up wallet: $e');
      rethrow;
    }
  }

  // Charge wallet
  Future<bool> charge(double amount) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      // Check if balance is sufficient
      final currentBalance = await getBalance();
      if (currentBalance < amount) {
        debugPrint('⚠️ Insufficient balance: $currentBalance < $amount');
        return false;
      }

      // Deduct from wallet
      final walletId = await _supabase.rpc('update_wallet_balance', params: {
        'p_user_id': userId,
        'p_amount': -amount, // Negative to deduct
      });

      // Log transaction
      await _supabase.from('wallet_transactions').insert({
        'wallet_id': walletId,
        'type': 'debit',
        'amount': amount,
        'description': 'Payment charge',
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ Wallet charged: -$amount');
      return true;
    } catch (e) {
      debugPrint('❌ Error charging wallet: $e');
      return false;
    }
  }

  // Refund to wallet
  Future<void> refund(double amount) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      // Add to wallet balance
      final walletId = await _supabase.rpc('update_wallet_balance', params: {
        'p_user_id': userId,
        'p_amount': amount,
      });

      // Log transaction
      await _supabase.from('wallet_transactions').insert({
        'wallet_id': walletId,
        'type': 'credit',
        'amount': amount,
        'description': 'Refund',
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ Wallet refunded: +$amount');
    } catch (e) {
      debugPrint('❌ Error refunding wallet: $e');
      rethrow;
    }
  }
}


