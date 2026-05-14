import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Obtener el ID del usuario actual de forma segura
  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  /// Guarda un programa en la nube. 
  /// Si la colección 'users' o la subcolección 'projects' no existen, 
  /// Firestore las creará automáticamente en este momento.
  Future<void> saveProject({
    required String name,
    required String code,
    required List<Map<String, dynamic>> obstacles,
  }) async {
    if (_userId == null) {
      throw Exception("Debes iniciar sesión para guardar en la nube");
    }

    final docRef = _db
        .collection('users')
        .doc(_userId)
        .collection('projects')
        .doc(name); // Usamos el nombre del proyecto como ID del documento

    await docRef.set({
      'name': name,
      'code': code,
      'obstacles': obstacles,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Obtiene un stream con todos los proyectos del usuario
  Stream<QuerySnapshot> getMyProjects() {
    if (_userId == null) return const Stream.empty();
    
    return _db
        .collection('users')
        .doc(_userId)
        .collection('projects')
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  /// Obtiene los comandos personalizados globales o del usuario
  Stream<QuerySnapshot> getCustomCommands() {
    return _db.collection('custom_commands').snapshots();
  }
}
