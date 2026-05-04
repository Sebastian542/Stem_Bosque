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

  // Registro de nuevo usuario con creación de perfil en Firestore
  Future<UserCredential?> signUp(String email, String password, String name) async {
    try {
      // 1. Crear el usuario en Firebase Auth
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );

      // 2. Crear el perfil en la colección 'users' de Firestore
      if (credential.user != null) {
        await _db.collection('users').doc(credential.user!.uid).set({
          'uid': credential.user!.uid,
          'name': name,
          'email': email,
          'role': 'student',
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
        });
      }

      return credential;
    } catch (e) {
      debugPrint("Error en Registro: $e");
      rethrow;
    }
  }
}
