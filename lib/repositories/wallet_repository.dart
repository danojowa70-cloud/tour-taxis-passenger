import '../services/wallet_service.dart';

class WalletRepository {
  final WalletService service;
  WalletRepository(this.service);

  double get balance => service.balance;
  List<Map<String, dynamic>> get ledger => service.ledger;
  void topUp(double amount) => service.topUp(amount);
  bool charge(double amount) => service.charge(amount);
  void refund(double amount) => service.refund(amount);
}


