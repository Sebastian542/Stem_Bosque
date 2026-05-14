import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/database_service.dart';
import '../theme/app_theme.dart';
import '../../models/project_model.dart';

class CloudExplorerScreen extends StatelessWidget {
  const CloudExplorerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Explorador en la Nube'),
        backgroundColor: AppTheme.currentLine,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: DatabaseService().getMyProjects(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.purple));
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AppTheme.red)));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off, size: 64, color: AppTheme.comment),
                  SizedBox(height: 16),
                  Text('No tienes proyectos en la nube', style: TextStyle(color: AppTheme.comment)),
                ],
              ),
            );
          }

          final projects = snapshot.data!.docs.map((doc) {
            return ProjectModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
          }).toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: projects.length,
            itemBuilder: (context, index) {
              final project = projects[index];
              return Card(
                color: AppTheme.currentLine,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const Icon(Icons.cloud_done, color: AppTheme.cyan),
                  title: Text(
                    project.name,
                    style: const TextStyle(color: AppTheme.foreground, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Actualizado: ${project.updatedAt.day}/${project.updatedAt.month}/${project.updatedAt.year}',
                    style: const TextStyle(color: AppTheme.comment, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: AppTheme.purple),
                  onTap: () {
                    Navigator.pop(context, project);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
