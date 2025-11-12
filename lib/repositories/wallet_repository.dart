import '../services/wallet_service.dart';

class WalletRepository {
  final WalletService service;
  WalletRepository(this.service);

  Future<double> getBalance() => service.getBalance();
  Future<List<Map<String, dynamic>>> getLedger() => service.getLedger();
  Future<void> topUp(double amount) => service.topUp(amount);
  Future<bool> charge(double amount) => service.charge(amount);
  Future<void> refund(double amount) => service.refund(amount);
}


