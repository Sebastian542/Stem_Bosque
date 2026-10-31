import 'package:cloud_firestore/cloud_firestore.dart';

class ProjectModel {
  final String id; // Nombre del archivo o ID único
  final String name;
  final String code; // El código DSL (kw inicio... etc)
  final List<Map<String, dynamic>> obstacles; // Posiciones del Modo Bloque
  final DateTime createdAt;
  final DateTime updatedAt;

  ProjectModel({
    required this.id,
    required this.name,
    required this.code,
    required this.obstacles,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'code': code,
      'obstacles': obstacles,
      'createdAt': createdAt,
      'updatedAt': FieldValue.serverTimestamp(), // Firestore genera la hora en el servidor
    };
  }

  static DateTime _asDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }

  factory ProjectModel.fromMap(Map<String, dynamic> map, String documentId) {
    return ProjectModel(
      id: documentId,
      name: map['name'] ?? 'Sin nombre',
      code: map['code'] ?? '',
      obstacles: [
        for (final item in (map['obstacles'] as List<dynamic>? ?? const []))
          Map<String, dynamic>.from(item as Map),
      ],
      createdAt: _asDate(map['createdAt']),
      updatedAt: _asDate(map['updatedAt'] ?? map['createdAt']),
    );
  }
}
