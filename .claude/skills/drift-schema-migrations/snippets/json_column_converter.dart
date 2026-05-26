// JSON column converter for Drift — stores Map<String, dynamic> as TEXT.
// Use when you have user-extensible / sparsely-populated metadata.

import 'dart:convert';
import 'package:drift/drift.dart';

class JsonColumnConverter extends TypeConverter<Map<String, dynamic>, String> {
  const JsonColumnConverter();

  @override
  Map<String, dynamic> fromSql(String fromDb) {
    if (fromDb.isEmpty) return const {};
    return jsonDecode(fromDb) as Map<String, dynamic>;
  }

  @override
  String toSql(Map<String, dynamic> value) => jsonEncode(value);
}
