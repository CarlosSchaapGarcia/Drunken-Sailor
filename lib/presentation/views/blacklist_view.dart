import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';

// Uses allBarsProvider (full dump) intentionally — this is a management screen,
// not a navigation screen. The user needs to see every bar in the database so
// they can inspect and toggle any entry regardless of their current location.
// Switching to a geohash-scoped query here would hide bars from other cities,
// making it impossible to unblacklist something added on a previous visit.
// The map and navigation providers use findNearbyBars; this screen does not.
class BlacklistView extends ConsumerStatefulWidget {
  const BlacklistView({Key? key}) : super(key: key);

  @override
  ConsumerState<BlacklistView> createState() => _BlacklistViewState();
}

class _BlacklistViewState extends ConsumerState<BlacklistView> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _showOnlyBlacklisted = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final barsAsync = ref.watch(allBarsProvider);
    final blacklisted = ref.watch(blacklistedBarIdsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0f172a),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1e293b),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Blacklist',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                'Blocked only',
                style: TextStyle(
                  color: _showOnlyBlacklisted
                      ? const Color(0xFF0f172a)
                      : const Color(0xFF94a3b8),
                  fontSize: 12,
                ),
              ),
              selected: _showOnlyBlacklisted,
              onSelected: (v) => setState(() => _showOnlyBlacklisted = v),
              selectedColor: const Color(0xFFef4444),
              backgroundColor: const Color(0xFF334155),
              checkmarkColor: const Color(0xFF0f172a),
              side: BorderSide.none,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search bars…',
                hintStyle: const TextStyle(color: Color(0xFF475569)),
                prefixIcon:
                    const Icon(Icons.search, color: Color(0xFF475569)),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear,
                            color: Color(0xFF475569)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF1e293b),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: barsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                  child: Text('Error: $e',
                      style: const TextStyle(color: Colors.white))),
              data: (bars) {
                final sorted = [...bars]
                  ..sort((a, b) => a.name.compareTo(b.name));

                final filtered = sorted.where((bar) {
                  if (_showOnlyBlacklisted && !blacklisted.contains(bar.id)) {
                    return false;
                  }
                  if (_query.isNotEmpty &&
                      !bar.name.toLowerCase().contains(_query)) {
                    return false;
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      _showOnlyBlacklisted
                          ? 'No blocked bars'
                          : 'No bars match "$_query"',
                      style: const TextStyle(color: Color(0xFF475569)),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final bar = filtered[i];
                    final isBlocked = blacklisted.contains(bar.id);
                    return ListTile(
                      title: Text(
                        bar.name,
                        style: TextStyle(
                          color: isBlocked
                              ? const Color(0xFFef4444)
                              : Colors.white,
                        ),
                      ),
                      subtitle: bar.gayFriendly
                          ? const Text('Gay friendly',
                              style: TextStyle(
                                  color: Color(0xFFec4899), fontSize: 12))
                          : null,
                      trailing: IconButton(
                        icon: Icon(
                          isBlocked
                              ? Icons.block
                              : Icons.check_circle_outline,
                          color: isBlocked
                              ? const Color(0xFFef4444)
                              : const Color(0xFF475569),
                        ),
                        onPressed: () async {
                          await ref
                              .read(blacklistedBarIdsProvider.notifier)
                              .toggle(bar.id);
                          ref.invalidate(top5BarsProvider);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
