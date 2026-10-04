import 'package:agenda_app/features/auth/presentation/session_providers.dart';
import 'package:agenda_app/features/inbox/domain/quick_add_parser.dart';
import 'package:agenda_app/features/tasks/data/task_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class QuickAddSheet extends ConsumerStatefulWidget {
  const QuickAddSheet({super.key});

  @override
  ConsumerState<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<QuickAddSheet> {
  final controller = TextEditingController();
  final parser = QuickAddParser();
  bool saving = false;

  @override
  void initState() {
    super.initState();
    controller.addListener(_refresh);
  }

  @override
  void dispose() {
    controller
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  Future<void> _save() async {
    if (controller.text.trim().isEmpty || saving) return;
    final user = ref.read(activeUserProvider).asData?.value;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connectez un profil avant de créer une tâche.'),
        ),
      );
      return;
    }
    setState(() => saving = true);
    final result = parser.parse(controller.text);
    await ref
        .read(taskRepositoryProvider)
        .createTask(
          userId: user.id,
          title: result.title,
          estimatedDurationMinutes: result.estimatedDurationMinutes,
          scheduledStartAt: result.scheduledStartAt,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final result = parser.parse(controller.text);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Ajout rapide',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            decoration: const InputDecoration(
              hintText: 'Réviser IA demain 18h 1h',
              prefixIcon: Icon(Icons.add_task),
            ),
          ),
          if (result.hasSuggestions) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (result.scheduledStartAt != null)
                  Chip(
                    avatar: const Icon(Icons.schedule, size: 18),
                    label: Text(
                      DateFormat(
                        'EEE d MMM · HH:mm',
                        'fr_FR',
                      ).format(result.scheduledStartAt!),
                    ),
                  ),
                if (result.estimatedDurationMinutes != null)
                  Chip(
                    avatar: const Icon(Icons.timer_outlined, size: 18),
                    label: Text('${result.estimatedDurationMinutes} min'),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  result.scheduledStartAt == null
                      ? 'Sera ajoutée à l’Inbox'
                      : 'Sera planifiée automatiquement',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              FilledButton.icon(
                onPressed: controller.text.trim().isEmpty || saving
                    ? null
                    : _save,
                icon: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_upward),
                label: const Text('Ajouter'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
