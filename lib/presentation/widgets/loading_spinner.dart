import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';

const _themeColors = {
  'pirate': Color(0xFFfbbf24),
  'submarine': Color(0xFF10b981),
  'nuclear': Color(0xFFef4444),
};

class LoadingSpinner extends ConsumerWidget {
  const LoadingSpinner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);
    final color = _themeColors[theme] ?? const Color(0xFF10b981);
    return Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(color),
        strokeWidth: 3,
      ),
    );
  }
}
