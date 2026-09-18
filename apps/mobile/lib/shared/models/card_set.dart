class CardSet {
  const CardSet({
    required this.id,
    required this.code,
    required this.name,
    required this.battingFields,
    required this.bowlingFields,
  });

  final String id;
  final String code;
  final String name;
  final List<String> battingFields;
  final List<String> bowlingFields;

  factory CardSet.fromJson(Map<String, dynamic> json) {
    final schema = json['statSchema'] as Map<String, dynamic>? ?? const {};
    return CardSet(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      battingFields: (schema['batting'] as List<dynamic>? ?? const []).cast<String>(),
      bowlingFields: (schema['bowling'] as List<dynamic>? ?? const []).cast<String>(),
    );
  }
}
