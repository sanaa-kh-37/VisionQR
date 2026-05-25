import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/scanned_code.dart';

class HistoryDatabase {
  static const String _keyOfDatabase = "scan_pro_history_logs";

  static Future<List<ScannedCode>> getItems() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? dataString = prefs.getString(_keyOfDatabase);
    if (dataString == null) return [];

    try {
      final List<dynamic> listJson = jsonDecode(dataString);
      return listJson.map((item) => ScannedCode.fromMap(item)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveItem(ScannedCode code) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<ScannedCode> items = await getItems();

    items.removeWhere((it) => it.value == code.value);
    items.insert(0, code);

    final String encoded = jsonEncode(items.map((it) => it.toMap()).toList());
    await prefs.setString(_keyOfDatabase, encoded);
  }

  static Future<void> clearItems() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyOfDatabase);
  }
}