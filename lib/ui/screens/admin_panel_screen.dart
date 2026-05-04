import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import 'command_creator_screen.dart';

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Panel de Administración', style: TextStyle(color: AppTheme.foreground)),
        backgroundColor: AppTheme.selection,
        iconTheme: const IconThemeData(color: AppTheme.foreground),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_rounded, color: AppTheme.green),
            tooltip: 'Crear Nuevo Comando',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CommandCreatorScreen()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error al cargar usuarios', style: TextStyle(color: AppTheme.red)));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.purple));
          }

          final users = snapshot.data!.docs;

          return ListView.separated(
            itemCount: users.length,
            separatorBuilder: (context, index) => const Divider(color: AppTheme.selection),
            itemBuilder: (context, index) {
              final userData = users[index].data() as Map<String, dynamic>;
              final String name = userData['name'] ?? 'Sin nombre';
              final String email = userData['email'] ?? 'Sin email';
              final String role = userData['role'] ?? 'nuevo usuario';
              final String uid = users[index].id;

              return ListTile(
                title: Text(name, style: const TextStyle(color: AppTheme.foreground, fontWeight: FontWeight.bold)),
                subtitle: Text('$email\nRol: $role', style: const TextStyle(color: AppTheme.comment)),
                isThreeLine: true,
                trailing: role != 'admin' ? PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppTheme.purple),
                  onSelected: (value) async {
                    await FirebaseFirestore.instance.collection('users').doc(uid).update({'role': value});
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'admin', child: Text('Hacer Admin')),
                    const PopupMenuItem(value: 'teacher', child: Text('Hacer Profesor')),
                    const PopupMenuItem(value: 'student', child: Text('Hacer Estudiante')),
                    const PopupMenuItem(value: 'nuevo usuario', child: Text('Resetear Rol')),
                  ],
                ) : const Icon(Icons.shield, color: AppTheme.yellow),
              );
            },
          );
        },
      ),
    );
  }
}
