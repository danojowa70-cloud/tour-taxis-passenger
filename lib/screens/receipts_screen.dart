import 'package:flutter/material.dart';
import '../services/receipts_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReceiptsScreen extends StatefulWidget {
  const ReceiptsScreen({super.key});

  @override
  State<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends State<ReceiptsScreen> {
  final _service = ReceiptsService(Supabase.instance.client);
  bool _loading = false;
  String? _lastPath;

  Future<void> _generate() async {
    setState(() => _loading = true);
    final path = await _service.generateReceiptPdf(rideId: 'sample', amount: 12.5);
    setState(() { _lastPath = path; _loading = false; });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Generated: $path')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        title: const Text('Receipts'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ElevatedButton(onPressed: _loading ? null : _generate, child: Text(_loading ? 'Generating…' : 'Generate Sample Receipt')),
              const SizedBox(height: 12),
              if (_lastPath != null) Text('Last: $_lastPath'),
            ],
          ),
        ),
      ),
    );
  }
}


