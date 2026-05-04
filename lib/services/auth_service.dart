import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Stream para escuchar cambios en el estado de autenticación
  Stream<User?> get user => _auth.authStateChanges();

  // Login con Email y Contraseña
  Future<UserCredential?> signIn(String email, String password) async {
    try {
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email, 
        password: password
      );
      
      // Actualizar fecha de último acceso en Firestore
      if (credential.user != null) {
        await _db.collection('users').doc(credential.user!.uid).update({
          'lastLogin': FieldValue.serverTimestamp(),
        });
      }
      
      return credential;
    } catch (e) {
      debugPrint("Error en Login: $e");
      rethrow;
    }
  }

  // Cerrar sesión
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Obtener datos del perfil del usuario actual
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await _db.collection('users').doc(user.uid).get();
      return doc.data();
    }
    return null;
  }

  // Registro de nuevo usuario con creación de perfil en Firestore
  Future<UserCredential?> signUp(String email, String password, String name) async {
    try {
      debugPrint("Intentando registrar usuario: $email");
      // 1. Crear el usuario en Firebase Auth
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );

      debugPrint("Usuario creado en Auth: ${credential.user?.uid}");

      // 2. Crear el perfil en la colección 'users' de Firestore
      if (credential.user != null) {
        final uid = credential.user!.uid;
        await _db.collection('users').doc(uid).set({
          'uid': uid,
          'name': name,
          'email': email,
          'role': 'nuevo usuario',
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
        });
        debugPrint("Documento creado en Firestore para el usuario: $uid con rol: nuevo usuario");
      }

      return credential;
    } catch (e) {
      debugPrint("ERROR CRÍTICO EN REGISTRO: $e");
      rethrow;
    }
  }
}
