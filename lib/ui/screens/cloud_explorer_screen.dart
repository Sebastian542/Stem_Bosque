import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/database_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../../models/project_model.dart';

class CloudExplorerScreen extends StatelessWidget {
  const CloudExplorerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Explorador en la Nube', overflow: TextOverflow.ellipsis),
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
            return Center(
              child: Padding(
                padding: EdgeInsets.all(r.horizontalPadding),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_off, size: r.scale(64), color: AppTheme.comment),
                    SizedBox(height: r.verticalPadding),
                    const Text(
                      'No tienes proyectos en la nube',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.comment),
                    ),
                  ],
                ),
              ),
            );
          }

          final projects = snapshot.data!.docs.map((doc) {
            return ProjectModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
          }).toList();

          return ResponsivePage(
            child: r.useTwoPane
                ? GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: r.isLarge ? 3 : 2,
                      mainAxisExtent: 96,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: projects.length,
                    itemBuilder: (context, index) => _ProjectTile(project: projects[index]),
                  )
                : ListView.builder(
                    itemCount: projects.length,
                    itemBuilder: (context, index) => _ProjectTile(project: projects[index]),
                  ),
          );
        },
      ),
    );
  }
}

class _ProjectTile extends StatelessWidget {
  const _ProjectTile({required this.project});

  final ProjectModel project;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.currentLine,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const Icon(Icons.cloud_done, color: AppTheme.cyan),
        title: Text(
          project.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppTheme.foreground, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Actualizado: ${project.updatedAt.day}/${project.updatedAt.month}/${project.updatedAt.year}',
          style: const TextStyle(color: AppTheme.comment, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppTheme.purple),
        onTap: () => Navigator.pop(context, project),
      ),
    );
  }
}
