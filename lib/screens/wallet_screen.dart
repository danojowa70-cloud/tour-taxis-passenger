import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/payments_providers.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        title: const Text('Wallet'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Balance', style: TextStyle(fontWeight: FontWeight.w700)),
                    Text('€${wallet.balance.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: ElevatedButton(onPressed: () { wallet.topUp(10); (context as Element).markNeedsBuild(); }, child: const Text('Top Up €10'))),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton(onPressed: () { if (wallet.charge(5)) (context as Element).markNeedsBuild(); }, child: const Text('Charge €5'))),
                ],
              ),
              const SizedBox(height: 12),
              Text('Ledger', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemBuilder: (_, i) {
                    final item = wallet.ledger[i];
                    return ListTile(
                      title: Text('${item['type']} · €${(item['amount'] as double).toStringAsFixed(2)}'),
                      subtitle: Text(item['at'] as String),
                    );
                  },
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemCount: wallet.ledger.length,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}


