class BarServiceException implements Exception {
  final String message;
  const BarServiceException(this.message);
  @override
  String toString() => 'BarServiceException: $message';
}
