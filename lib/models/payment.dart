class PaymentRecord {
  final String id;
  final String method; // Cash, Card, Wallet
  final double amount;
  final String status; // Paid, Pending, Failed
  final DateTime dateTime;

  const PaymentRecord({required this.id, required this.method, required this.amount, required this.status, required this.dateTime});
}


