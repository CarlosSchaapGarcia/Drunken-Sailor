import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';

const _themeIcons = {
  'pirate': Icons.sailing,
  'submarine': Icons.water,
  'nuclear': Icons.warning_amber_rounded,
};

const _themeColors = {
  'pirate': Color(0xFFfbbf24),
  'submarine': Color(0xFF10b981),
  'nuclear': Color(0xFFef4444),
};

class ErrorDisplay extends ConsumerWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorDisplay({Key? key, required this.message, this.onRetry}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);
    final color = _themeColors[theme] ?? const Color(0xFF94a3b8);
    final icon = _themeIcons[theme] ?? Icons.error_outline;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF94a3b8), fontSize: 14),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
                style: OutlinedButton.styleFrom(foregroundColor: color, side: BorderSide(color: color)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
