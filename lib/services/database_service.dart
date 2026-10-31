import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Obtener el ID del usuario actual de forma segura
  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  /// Crea las colecciones de la nube si aún no existen.
  /// Firestore solo materializa una colección al escribir un documento.
  Future<void> ensureCollections() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userRef = _db.collection('users').doc(user.uid);
    final userSnap = await userRef.get();
    final email = user.email ?? '';

    if (!userSnap.exists) {
      await userRef.set({
        'uid': user.uid,
        'email': email,
        'emailLower': email.toLowerCase(),
        'name': (user.displayName == null || user.displayName!.trim().isEmpty)
            ? 'Usuario'
            : user.displayName,
        'role': 'nuevo usuario',
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      });
    } else {
      await userRef.set({
        'email': email.isEmpty ? (userSnap.data()?['email'] ?? '') : email,
        'emailLower': email.toLowerCase(),
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await _ensureDoc(userRef.collection('projects').doc('_schema'), {
      'name': '_schema',
      'system': true,
      'code': '',
      'obstacles': <Map<String, dynamic>>[],
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _ensureDoc(_db.collection('custom_commands').doc('_schema'), {
      'system': true,
      'keyword': '',
      'description': '',
      'script': '',
      'createdBy': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _ensureDoc(_db.collection('program_transfers').doc('_schema'), {
      'system': true,
      'name': '_schema',
      'code': '',
      'obstacles': <Map<String, dynamic>>[],
      'fromUid': user.uid,
      'fromEmail': email,
      'fromName': '',
      'toUid': user.uid,
      'toEmail': email,
      'toName': '',
      'read': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _ensureDoc(
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> data,
  ) async {
    try {
      await ref.set(data);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return;
      rethrow;
    }
  }

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

  /// Obtiene los comandos personalizados globales (requiere sesión iniciada).
  Stream<QuerySnapshot> getCustomCommands() {
    if (_userId == null) return const Stream.empty();

    return _db.collection('custom_commands').snapshots();
  }

  /// Envía el programa a otra cuenta registrada, buscándola por correo.
  Future<String> sendProgramToEmail({
    required String toEmail,
    required String name,
    required String code,
    required List<Map<String, dynamic>> obstacles,
  }) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) {
      throw Exception('Debes iniciar sesión para enviar por la nube');
    }

    final email = toEmail.trim();
    if (email.isEmpty || !email.contains('@')) {
      throw Exception('Escribe un correo válido');
    }
    if (me.email != null && me.email!.toLowerCase() == email.toLowerCase()) {
      throw Exception('No puedes enviarte el programa a ti mismo');
    }
    if (code.trim().isEmpty) {
      throw Exception('No hay programa para enviar');
    }

    await ensureCollections();

    final recipient = await _findUserByEmail(email);
    if (recipient == null) {
      throw Exception('No hay una cuenta registrada con ese correo');
    }

    final profile = await _db.collection('users').doc(me.uid).get();
    final fromName = (profile.data()?['name'] as String?)?.trim();

    await _db.collection('program_transfers').add({
      'name': name.trim().isEmpty ? 'Programa' : name.trim(),
      'code': code,
      'obstacles': obstacles,
      'fromUid': me.uid,
      'fromEmail': me.email ?? '',
      'fromName': (fromName == null || fromName.isEmpty) ? (me.email ?? 'Usuario') : fromName,
      'toUid': recipient.id,
      'toEmail': (recipient.data()['email'] as String?) ?? email,
      'toName': (recipient.data()['name'] as String?) ?? '',
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final toName = (recipient.data()['name'] as String?)?.trim();
    if (toName != null && toName.isNotEmpty) return toName;
    return (recipient.data()['email'] as String?) ?? email;
  }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> _findUserByEmail(
    String email,
  ) async {
    final byLower = await _db
        .collection('users')
        .where('emailLower', isEqualTo: email.toLowerCase())
        .limit(1)
        .get();
    if (byLower.docs.isNotEmpty) return byLower.docs.first;

    final exact = await _db
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    if (exact.docs.isNotEmpty) return exact.docs.first;

    final lower = email.toLowerCase();
    if (lower == email) return null;

    final folded = await _db
        .collection('users')
        .where('email', isEqualTo: lower)
        .limit(1)
        .get();
    if (folded.docs.isEmpty) return null;
    return folded.docs.first;
  }

  /// Programas que otros usuarios enviaron a la cuenta actual.
  Stream<QuerySnapshot<Map<String, dynamic>>> incomingPrograms() {
    if (_userId == null) return const Stream.empty();

    return _db
        .collection('program_transfers')
        .where('toUid', isEqualTo: _userId)
        .snapshots();
  }

  Future<void> markTransferRead(String transferId) async {
    if (_userId == null) return;
    await _db.collection('program_transfers').doc(transferId).update({
      'read': true,
    });
  }

  /// Guarda un comando personalizado en Firestore.
  Future<void> saveCustomCommand({
    required String keyword,
    required String description,
    required String script,
  }) async {
    if (_userId == null) {
      throw Exception('Debes iniciar sesión para crear comandos personalizados');
    }

    await _db.collection('custom_commands').add({
      'keyword': keyword.trim().toUpperCase(),
      'description': description.trim(),
      'script': script.trim(),
      'createdBy': _userId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
