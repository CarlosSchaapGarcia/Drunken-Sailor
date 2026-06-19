import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';

class BlacklistView extends ConsumerWidget {
  const BlacklistView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final barsAsync = ref.watch(allBarsProvider);
    final blacklisted = ref.watch(blacklistedBarIdsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0f172a),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1e293b),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Blacklist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: barsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white))),
        data: (bars) {
          final sorted = [...bars]..sort((a, b) => a.name.compareTo(b.name));
          return ListView.builder(
            itemCount: sorted.length,
            itemBuilder: (context, i) {
              final bar = sorted[i];
              final isBlocked = blacklisted.contains(bar.id);
              return ListTile(
                title: Text(
                  bar.name,
                  style: TextStyle(
                    color: isBlocked ? const Color(0xFFef4444) : Colors.white,
                  ),
                ),
                subtitle: bar.gayFriendly
                    ? const Text('Gay friendly',
                        style: TextStyle(color: Color(0xFFec4899), fontSize: 12))
                    : null,
                trailing: IconButton(
                  icon: Icon(
                    isBlocked ? Icons.block : Icons.check_circle_outline,
                    color: isBlocked
                        ? const Color(0xFFef4444)
                        : const Color(0xFF475569),
                  ),
                  onPressed: () async {
                    await ref.read(blacklistedBarIdsProvider.notifier).toggle(bar.id);
                    ref.invalidate(top5BarsProvider);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
