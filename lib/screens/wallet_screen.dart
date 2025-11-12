import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/payments_providers.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  double _balance = 0;
  List<Map<String, dynamic>> _ledger = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWalletData();
  }

  Future<void> _loadWalletData() async {
    setState(() => _loading = true);
    try {
      final wallet = ref.read(walletRepositoryProvider);
      final balance = await wallet.getBalance();
      final ledger = await wallet.getLedger();
      setState(() {
        _balance = balance;
        _ledger = ledger;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading wallet: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _handleTopUp(double amount) async {
    try {
      final wallet = ref.read(walletRepositoryProvider);
      await wallet.topUp(amount);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Topped up KSh ${amount.toStringAsFixed(0)}')),
        );
        _loadWalletData(); // Refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleCharge(double amount) async {
    try {
      final wallet = ref.read(walletRepositoryProvider);
      final success = await wallet.charge(amount);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Charged KSh ${amount.toStringAsFixed(0)}')),
          );
          _loadWalletData(); // Refresh
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Insufficient balance'), backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        title: const Text('Wallet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadWalletData,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green.shade600, Colors.green.shade800],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Balance',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Text(
                                    'KSh ',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    _balance.toStringAsFixed(2),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 36,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Icon(
                            Icons.account_balance_wallet,
                            color: Colors.white70,
                            size: 48,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _handleTopUp(100),
                            icon: const Icon(Icons.add),
                            label: const Text('Top Up KSh 100'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _handleCharge(50),
                            icon: const Icon(Icons.remove),
                            label: const Text('Charge KSh 50'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Transaction History',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _ledger.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.receipt_long,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No transactions yet',
                                    style: TextStyle(color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemBuilder: (_, i) {
                                final item = _ledger[i];
                                final isCredit = item['type'] == 'credit';
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: isCredit
                                        ? Colors.green.shade100
                                        : Colors.red.shade100,
                                    child: Icon(
                                      isCredit ? Icons.add : Icons.remove,
                                      color: isCredit ? Colors.green : Colors.red,
                                    ),
                                  ),
                                  title: Text(
                                    item['description'] ?? item['type'],
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Text(
                                    _formatDate(item['at'] as String),
                                    style: TextStyle(color: Colors.grey.shade600),
                                  ),
                                  trailing: Text(
                                    '${isCredit ? "+" : "-"}KSh ${(item['amount'] as num).toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      color: isCredit ? Colors.green : Colors.red,
                                    ),
                                  ),
                                );
                              },
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemCount: _ledger.length,
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays == 0) {
        return 'Today at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      } else if (diff.inDays == 1) {
        return 'Yesterday';
      } else if (diff.inDays < 7) {
        return '${diff.inDays} days ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return isoDate;
    }
  }
}


