class Household {
  final String id;
  final String name;

  Household({required this.id, required this.name});

  factory Household.fromJson(Map<String, dynamic> json) {
    final idValue = json['id'];
    final nameValue = json['name'];
    return Household(
      id: idValue?.toString() ?? '',
      name: nameValue == null || (nameValue is String && nameValue.isEmpty)
          ? 'Unnamed Household'
          : nameValue.toString(),
    );
  }
}
