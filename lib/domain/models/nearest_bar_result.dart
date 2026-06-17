import 'bar.dart';

class NearestBarResult {
  final Bar bar;
  final int distanceM;
  final bool isOpen;

  const NearestBarResult({
    required this.bar,
    required this.distanceM,
    required this.isOpen,
  });
}
