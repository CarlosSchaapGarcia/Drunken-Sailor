class OpeningHours {
  final int opens;  // minutes since midnight
  final int closes; // minutes since midnight

  const OpeningHours({required this.opens, required this.closes});

  factory OpeningHours.fromJson(Map<dynamic, dynamic> json) => OpeningHours(
        opens: json['opens'] as int? ?? 0,
        closes: json['closes'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {'opens': opens, 'closes': closes};

  @override
  bool operator ==(Object other) =>
      other is OpeningHours && opens == other.opens && closes == other.closes;

  @override
  int get hashCode => Object.hash(opens, closes);
}
