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

    return DefaultTabController(
      length: 2,
      child: Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Explorador en la Nube', overflow: TextOverflow.ellipsis),
        backgroundColor: AppTheme.currentLine,
        bottom: const TabBar(
          indicatorColor: AppTheme.cyan,
          labelColor: AppTheme.cyan,
          unselectedLabelColor: AppTheme.comment,
          tabs: [
            Tab(text: 'Mis proyectos'),
            Tab(text: 'Recibidos'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          _myProjects(context, r),
          _incoming(context, r),
        ],
      ),
      ),
    );
  }

  Widget _myProjects(BuildContext context, Responsive r) {
    return StreamBuilder<QuerySnapshot>(
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
            final data = doc.data() as Map<String, dynamic>;
            if (data['system'] == true) return null;
            return ProjectModel.fromMap(data, doc.id);
          }).whereType<ProjectModel>().toList();

          if (projects.isEmpty) {
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
      );
  }

  Widget _incoming(BuildContext context, Responsive r) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: DatabaseService().incomingPrograms(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.purple));
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(r.horizontalPadding),
              child: Text(
                'No se pudieron cargar los programas recibidos.\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.red),
              ),
            ),
          );
        }

        final docs = (snapshot.data?.docs.toList() ?? [])
            .where((doc) => doc.data()['system'] != true)
            .toList();
        docs.sort((a, b) {
          final aDate = (a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          final bDate = (b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          return bDate.compareTo(aDate);
        });

        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(r.horizontalPadding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.move_to_inbox, size: r.scale(64), color: AppTheme.comment),
                  SizedBox(height: r.verticalPadding),
                  const Text(
                    'Nadie te ha enviado un programa todavía',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.comment),
                  ),
                ],
              ),
            ),
          );
        }

        return ResponsivePage(
          child: ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final project = ProjectModel.fromMap(data, doc.id);
              final fromName = (data['fromName'] as String?)?.trim();
              final fromEmail = (data['fromEmail'] as String?) ?? '';
              final sender = (fromName == null || fromName.isEmpty) ? fromEmail : fromName;
              return _IncomingTile(
                project: project,
                sender: sender,
                unread: data['read'] != true,
              );
            },
          ),
        );
      },
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

class _IncomingTile extends StatelessWidget {
  const _IncomingTile({
    required this.project,
    required this.sender,
    required this.unread,
  });

  final ProjectModel project;
  final String sender;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.currentLine,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(
          unread ? Icons.mark_email_unread : Icons.forward_to_inbox,
          color: unread ? AppTheme.green : AppTheme.cyan,
        ),
        title: Text(
          project.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppTheme.foreground, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'De $sender',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppTheme.comment, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppTheme.purple),
        onTap: () async {
          try {
            await DatabaseService().markTransferRead(project.id);
          } catch (_) {}
          if (context.mounted) Navigator.pop(context, project);
        },
      ),
    );
  }
}
