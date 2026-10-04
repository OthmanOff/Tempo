import 'package:agenda_app/core/sync/sync_engine.dart';
import 'package:agenda_app/core/notifications/notification_service.dart';
import 'package:agenda_app/features/auth/presentation/session_providers.dart';
import 'package:agenda_app/features/calendar/data/calendar_source_repository.dart';
import 'package:agenda_app/features/calendar/data/ics_api_service.dart';
import 'package:agenda_app/core/theme/app_spacing.dart';
import 'package:agenda_app/core/theme/app_theme.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});
  static const routePath = '/settings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final sync = ref.watch(syncEngineProvider);
    final user = ref.watch(activeUserProvider).asData?.value;
    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          Text('Apparence', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                RadioListTile(
                  title: const Text('Système'),
                  value: ThemeMode.system,
                  groupValue: themeMode,
                  onChanged: (value) =>
                      ref.read(themeModeProvider.notifier).state = value!,
                ),
                RadioListTile(
                  title: const Text('Clair'),
                  value: ThemeMode.light,
                  groupValue: themeMode,
                  onChanged: (value) =>
                      ref.read(themeModeProvider.notifier).state = value!,
                ),
                RadioListTile(
                  title: const Text('Sombre'),
                  value: ThemeMode.dark,
                  groupValue: themeMode,
                  onChanged: (value) =>
                      ref.read(themeModeProvider.notifier).state = value!,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          Text(
            'Synchronisation',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: sync.status == SyncStatus.syncing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              title: Text(_syncLabel(sync)),
              subtitle: sync.error == null
                  ? null
                  : Text(
                      sync.error.toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
              trailing: IconButton(
                tooltip: 'Synchroniser',
                onPressed: sync.status == SyncStatus.syncing
                    ? null
                    : () => ref.read(syncEngineProvider.notifier).synchronize(),
                icon: const Icon(Icons.refresh),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          Text('Notifications', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Autoriser les rappels'),
              subtitle: const Text(
                'Les rappels sont calculés et programmés sur cet appareil.',
              ),
              trailing: FilledButton.tonal(
                onPressed: () => _requestNotifications(context, ref),
                child: const Text('Autoriser'),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Calendriers externes',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Importer un fichier ICS',
                onPressed: user == null ? null : () => _importIcs(context, ref),
                icon: const Icon(Icons.upload_file),
              ),
              IconButton(
                tooltip: 'Ajouter une URL ICS',
                onPressed: user == null
                    ? null
                    : () => _addUrl(context, ref, user.id),
                icon: const Icon(Icons.add_link),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: user == null
                ? const ListTile(
                    title: Text(
                      'Connectez un profil pour gérer les calendriers.',
                    ),
                  )
                : StreamBuilder(
                    stream: ref
                        .watch(calendarSourceRepositoryProvider)
                        .watch(user.id),
                    builder: (context, snapshot) {
                      final sources = snapshot.data ?? const [];
                      if (sources.isEmpty) {
                        return const ListTile(
                          leading: Icon(Icons.calendar_month_outlined),
                          title: Text('Aucune source externe'),
                        );
                      }
                      return Column(
                        children: sources
                            .map(
                              (source) => ListTile(
                                leading: Icon(
                                  source.type == 'ics_url'
                                      ? Icons.link
                                      : Icons.description_outlined,
                                ),
                                title: Text(source.name),
                                subtitle: Text(
                                  source.lastSyncedAt == null
                                      ? 'Jamais synchronisé'
                                      : 'Mis à jour ${DateFormat.yMd('fr_FR').add_Hm().format(source.lastSyncedAt!.toLocal())}',
                                ),
                                trailing: source.type == 'ics_url'
                                    ? IconButton(
                                        tooltip: 'Resynchroniser',
                                        onPressed: () => _syncSource(
                                          context,
                                          ref,
                                          source.id,
                                        ),
                                        icon: const Icon(Icons.sync),
                                      )
                                    : null,
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
          ),
          const SizedBox(height: AppSpacing.section),
          Text('Calendrier', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.language),
                  title: Text('Fuseau horaire'),
                  trailing: Text('Europe/Paris'),
                ),
                ListTile(
                  leading: Icon(Icons.calendar_month),
                  title: Text('Premier jour de la semaine'),
                  trailing: Text('Lundi'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(sessionControllerProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout),
            label: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
  }

  Future<void> _importIcs(BuildContext context, WidgetRef ref) async {
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['ics'],
        withData: true,
      );
      final file = picked?.files.single;
      if (file?.bytes == null) return;
      await ref
          .read(icsApiServiceProvider)
          .importFile(
            name: file!.name.replaceFirst(
              RegExp(r'\.ics$', caseSensitive: false),
              '',
            ),
            bytes: file.bytes!,
          );
      await ref.read(syncEngineProvider.notifier).synchronize();
      if (context.mounted) _message(context, 'Calendrier importé');
    } catch (error) {
      if (context.mounted) _message(context, 'Import impossible : $error');
    }
  }

  Future<void> _requestNotifications(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final granted = await ref
        .read(notificationServiceProvider)
        .requestPermission();
    if (!context.mounted) return;
    _message(
      context,
      granted
          ? 'Notifications autorisées'
          : 'Notifications indisponibles ou refusées',
    );
  }

  Future<void> _addUrl(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) async {
    final name = TextEditingController();
    final url = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un calendrier ICS'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Nom'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: url,
              decoration: const InputDecoration(labelText: 'URL HTTPS'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    try {
      final id = await ref
          .read(calendarSourceRepositoryProvider)
          .createUrl(userId: userId, name: name.text, url: url.text);
      await ref.read(syncEngineProvider.notifier).synchronize();
      await ref.read(icsApiServiceProvider).syncSource(id);
      await ref.read(syncEngineProvider.notifier).synchronize();
      if (context.mounted) _message(context, 'Abonnement ajouté');
    } catch (error) {
      if (context.mounted) _message(context, 'Ajout impossible : $error');
    } finally {
      name.dispose();
      url.dispose();
    }
  }

  Future<void> _syncSource(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    try {
      await ref.read(icsApiServiceProvider).syncSource(id);
      await ref.read(syncEngineProvider.notifier).synchronize();
      if (context.mounted) _message(context, 'Calendrier actualisé');
    } catch (error) {
      if (context.mounted) {
        _message(context, 'Synchronisation impossible : $error');
      }
    }
  }

  void _message(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _syncLabel(SyncState sync) {
    if (sync.status == SyncStatus.syncing) {
      return 'Synchronisation en cours';
    }
    if (sync.status == SyncStatus.failed) {
      return 'Échec de la synchronisation';
    }
    if (sync.lastSyncedAt != null) {
      return 'Synchronisé à ${DateFormat.Hm().format(sync.lastSyncedAt!.toLocal())}';
    }
    return 'Jamais synchronisé';
  }
}
