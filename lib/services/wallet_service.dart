class WalletService {
  double _balance = 0;
  final List<Map<String, dynamic>> _ledger = [];

  double get balance => _balance;
  List<Map<String, dynamic>> get ledger => List.unmodifiable(_ledger);

  void topUp(double amount) {
    _balance += amount;
    _ledger.insert(0, { 'type': 'topup', 'amount': amount, 'at': DateTime.now().toIso8601String() });
  }

  bool charge(double amount) {
    if (_balance >= amount) {
      _balance -= amount;
      _ledger.insert(0, { 'type': 'debit', 'amount': amount, 'at': DateTime.now().toIso8601String() });
      return true;
    }
    return false;
  }

  void refund(double amount) {
    _balance += amount;
    _ledger.insert(0, { 'type': 'refund', 'amount': amount, 'at': DateTime.now().toIso8601String() });
  }
}


