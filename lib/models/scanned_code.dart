class ScannedCode {
  final String id;
  final String type;
  final String value;
  final String title;
  final String dateTime;
  bool isFavorite;
  final String? studentName;
  final String? studentRegNo;

  ScannedCode({
    required this.id,
    required this.type,
    required this.value,
    required this.title,
    required this.dateTime,
    this.isFavorite = false,
    this.studentName,
    this.studentRegNo,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type,
    'value': value,
    'title': title,
    'dateTime': dateTime,
    'isFavorite': isFavorite ? 1 : 0,
    'studentName': studentName,
    'studentRegNo': studentRegNo,
  };

  factory ScannedCode.fromMap(Map<String, dynamic> map) => ScannedCode(
    id: map['id'],
    type: map['type'],
    value: map['value'],
    title: map['title'],
    dateTime: map['dateTime'],
    isFavorite: map['isFavorite'] == 1,
    studentName: map['studentName'],
    studentRegNo: map['studentRegNo'],
  );
}