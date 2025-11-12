import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/boarding_pass.dart';
import '../providers/boarding_pass_providers.dart';

class BoardingPassesScreen extends ConsumerWidget {
  const BoardingPassesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeBoardingPassesProvider);
    final past = ref.watch(pastBoardingPassesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Boarding Passes'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(boardingPassProvider.notifier).refresh();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (active.isNotEmpty) ...[
              _SectionHeader(title: 'Upcoming', theme: theme),
              ...active.map((p) => _PassTile(pass: p)),
            ] else ...[
              const _EmptyState(message: 'No upcoming boarding passes')
            ],
            const SizedBox(height: 16),
            _SectionHeader(title: 'Past', theme: theme),
            if (past.isNotEmpty)
              ...past.map((p) => _PassTile(pass: p))
            else
              const _EmptyState(message: 'No past boarding passes'),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final ThemeData theme;
  const _SectionHeader({required this.title, required this.theme});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
    );
  }
}

class _PassTile extends StatelessWidget {
  final BoardingPass pass;
  const _PassTile({required this.pass});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(child: Text(pass.vehicleType.emoji)),
      title: Text('${pass.origin ?? 'N/A'} → ${pass.destination}'),
      subtitle: Text('${pass.vehicleTypeDisplayName} • ${pass.statusDisplayName}'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).pushNamed('/boarding-pass', arguments: pass.id),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
