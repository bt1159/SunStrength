class InvalidPixelWidth implements Exception {
  final String message;
  final int pixelWidth;
  final int iterableLength;

  InvalidPixelWidth({
    required this.pixelWidth,
    required this.iterableLength,
    this.message = '',
  });

  @override
  String toString() {
    return 'InvalidPixelWidth: ${message == '' ? '' : '$message, '} pixelWidth: $pixelWidth, iterableLength: $iterableLength';
  }
}
