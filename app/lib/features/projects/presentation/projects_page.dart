import 'package:agenda_app/core/database/app_database.dart';
import 'package:agenda_app/core/theme/app_spacing.dart';
import 'package:agenda_app/core/widgets/empty_state.dart';
import 'package:agenda_app/features/auth/presentation/session_providers.dart';
import 'package:agenda_app/features/projects/data/project_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProjectsPage extends ConsumerStatefulWidget {
  const ProjectsPage({super.key});
  static const routePath = '/projects';

  @override
  ConsumerState<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends ConsumerState<ProjectsPage> {
  Future<void> _createProject(LocalUser user) async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final result = await showDialog<({String name, String description})>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nouveau projet'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Nom du projet'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (facultative)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) return;
              Navigator.pop(dialogContext, (
                name: nameController.text,
                description: descriptionController.text,
              ));
            },
            child: const Text('Créer'),
          ),
        ],
      ),
    );
    nameController.dispose();
    descriptionController.dispose();
    if (result == null || !mounted) return;
    try {
      await ref
          .read(projectRepositoryProvider)
          .create(
            userId: user.id,
            name: result.name,
            description: result.description,
          );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de créer le projet.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(activeUserProvider).asData?.value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Projets'),
        actions: [
          IconButton(
            tooltip: 'Créer un projet',
            onPressed: user == null ? null : () => _createProject(user),
            icon: const Icon(Icons.create_new_folder_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: user == null
          ? const EmptyState(
              icon: Icons.person_outline,
              title: 'Aucun profil local',
              message: 'Une session est nécessaire pour afficher vos projets.',
            )
          : StreamBuilder<List<LocalProject>>(
              stream: ref
                  .watch(projectRepositoryProvider)
                  .watchProjects(user.id),
              builder: (context, snapshot) {
                final projects = snapshot.data ?? const [];
                if (projects.isEmpty) {
                  return EmptyState(
                    icon: Icons.folder_outlined,
                    title: 'Aucun projet',
                    message: 'Créez un projet pour regrouper vos tâches.',
                    action: FilledButton.icon(
                      onPressed: () => _createProject(user),
                      icon: const Icon(Icons.add),
                      label: const Text('Créer un projet'),
                    ),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(AppSpacing.page),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 360,
                    mainAxisExtent: 170,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: projects.length,
                  itemBuilder: (context, index) =>
                      _ProjectCard(project: projects[index]),
                );
              },
            ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project});
  final LocalProject project;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.folder_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 34,
              ),
              const Spacer(),
              Text(project.name, style: Theme.of(context).textTheme.titleLarge),
              if (project.description != null) ...[
                const SizedBox(height: 4),
                Text(
                  project.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
