import 'package:agenda_app/core/database/app_database.dart';
import 'package:agenda_app/core/theme/app_spacing.dart';
import 'package:agenda_app/core/widgets/empty_state.dart';
import 'package:agenda_app/features/auth/presentation/session_providers.dart';
import 'package:agenda_app/features/projects/data/project_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProjectsPage extends ConsumerWidget {
  const ProjectsPage({super.key});
  static const routePath = '/projects';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(activeUserProvider).asData?.value;
    return Scaffold(
      appBar: AppBar(title: const Text('Projets')),
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
                  return const EmptyState(
                    icon: Icons.folder_outlined,
                    title: 'Aucun projet',
                    message:
                        'Créez un projet pour regrouper vos tâches et activités.',
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
