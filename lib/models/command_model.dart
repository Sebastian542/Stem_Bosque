import 'package:cloud_firestore/cloud_firestore.dart';

class CustomCommand {
  final String id;
  final String keyword;      // El nombre del comando (ej: SALTAR)
  final String description;  // Para qué sirve
  final List<String> script; // Qué comandos básicos ejecuta internamente
  final String createdBy;

  CustomCommand({
    required this.id,
    required this.keyword,
    required this.description,
    required this.script,
    required this.createdBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'keyword': keyword.toUpperCase(),
      'description': description,
      'script': script,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory CustomCommand.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CustomCommand(
      id: doc.id,
      keyword: data['keyword'] ?? '',
      description: data['description'] ?? '',
      script: List<String>.from(data['script'] ?? []),
      createdBy: data['createdBy'] ?? '',
    );
  }
}
