class ScannedCode {
  final String id;
  final String type;
  final String value;
  final String title;
  final String dateTime;
  bool isFavorite;

  ScannedCode({
    required this.id,
    required this.type,
    required this.value,
    required this.title,
    required this.dateTime,
    this.isFavorite = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type,
    'value': value,
    'title': title,
    'dateTime': dateTime,
    'isFavorite': isFavorite ? 1 : 0,
  };

  factory ScannedCode.fromMap(Map<String, dynamic> map) => ScannedCode(
    id: map['id'],
    type: map['type'],
    value: map['value'],
    title: map['title'],
    dateTime: map['dateTime'],
    isFavorite: map['isFavorite'] == 1,
  );
}