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

  factory ProjectModel.fromMap(Map<String, dynamic> map, String documentId) {
    return ProjectModel(
      id: documentId,
      name: map['name'] ?? 'Sin nombre',
      code: map['code'] ?? '',
      obstacles: List<Map<String, dynamic>>.from(map['obstacles'] ?? []),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }
}
