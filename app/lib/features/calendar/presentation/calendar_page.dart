import 'package:agenda_app/core/database/app_database.dart';
import 'package:agenda_app/core/theme/app_spacing.dart';
import 'package:agenda_app/core/utils/date_ranges.dart';
import 'package:agenda_app/core/widgets/empty_state.dart';
import 'package:agenda_app/features/auth/presentation/session_providers.dart';
import 'package:agenda_app/features/calendar/data/calendar_repository.dart';
import 'package:agenda_app/features/tasks/data/task_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});
  static const routePath = '/calendar';

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  DateTime selectedDate = DateTime.now();

  Future<void> _createEvent(LocalUser user) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CreateEventSheet(
        initialDate: selectedDate,
        onSave:
            ({
              required title,
              required startAt,
              required endAt,
              required description,
              required location,
            }) => ref
                .read(calendarRepositoryProvider)
                .createEvent(
                  userId: user.id,
                  title: title,
                  startAt: startAt,
                  endAt: endAt,
                  description: description,
                  location: location,
                ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(activeUserProvider).asData?.value;
    final range = localDayRange(selectedDate);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendrier'),
        actions: [
          IconButton(
            tooltip: 'Créer un événement',
            onPressed: user == null ? null : () => _createEvent(user),
            icon: const Icon(Icons.add),
          ),
          IconButton(
            tooltip: 'Jour précédent',
            onPressed: () => setState(
              () =>
                  selectedDate = selectedDate.subtract(const Duration(days: 1)),
            ),
            icon: const Icon(Icons.chevron_left),
          ),
          TextButton(
            onPressed: () => setState(() => selectedDate = DateTime.now()),
            child: const Text('Aujourd’hui'),
          ),
          IconButton(
            tooltip: 'Jour suivant',
            onPressed: () => setState(
              () => selectedDate = selectedDate.add(const Duration(days: 1)),
            ),
            icon: const Icon(Icons.chevron_right),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: user == null
          ? const EmptyState(
              icon: Icons.person_outline,
              title: 'Aucun profil local',
              message:
                  'Une session est nécessaire pour afficher le calendrier.',
            )
          : StreamBuilder<List<LocalTask>>(
              stream: ref
                  .watch(taskRepositoryProvider)
                  .watchTasks(userId: user.id),
              builder: (context, allTaskSnapshot) {
                final unplanned = (allTaskSnapshot.data ?? const <LocalTask>[])
                    .where(
                      (task) =>
                          task.scheduledStartAt == null &&
                          task.status != 'completed',
                    )
                    .toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.page,
                        8,
                        AppSpacing.page,
                        4,
                      ),
                      child: Text(
                        DateFormat.yMMMMEEEEd('fr_FR').format(selectedDate),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    _PlanningTray(tasks: unplanned),
                    Expanded(
                      child: StreamBuilder<List<LocalEvent>>(
                        stream: ref
                            .watch(calendarRepositoryProvider)
                            .watchEvents(
                              userId: user.id,
                              from: range.start,
                              to: range.end,
                            ),
                        builder: (context, eventSnapshot) {
                          return StreamBuilder<List<LocalTask>>(
                            stream: ref
                                .watch(calendarRepositoryProvider)
                                .watchScheduledTasks(
                                  userId: user.id,
                                  from: range.start,
                                  to: range.end,
                                ),
                            builder: (context, taskSnapshot) => _DayTimeline(
                              date: selectedDate,
                              events: eventSnapshot.data ?? const [],
                              tasks: taskSnapshot.data ?? const [],
                              repository: ref.read(taskRepositoryProvider),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

typedef _SaveEvent =
    Future<void> Function({
      required String title,
      required DateTime startAt,
      required DateTime endAt,
      required String description,
      required String location,
    });

class _CreateEventSheet extends StatefulWidget {
  const _CreateEventSheet({required this.initialDate, required this.onSave});

  final DateTime initialDate;
  final _SaveEvent onSave;

  @override
  State<_CreateEventSheet> createState() => _CreateEventSheetState();
}

class _CreateEventSheetState extends State<_CreateEventSheet> {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final locationController = TextEditingController();
  late DateTime date;
  late TimeOfDay startTime;
  late TimeOfDay endTime;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    date = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
    final now = DateTime.now();
    final nextHour = now.hour == 23 ? 22 : now.hour + 1;
    startTime = TimeOfDay(hour: nextHour, minute: 0);
    endTime = TimeOfDay(hour: nextHour + 1, minute: 0);
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    locationController.dispose();
    super.dispose();
  }

  DateTime _at(TimeOfDay time) =>
      DateTime(date.year, date.month, date.day, time.hour, time.minute);

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (selected != null) setState(() => date = selected);
  }

  Future<void> _pickTime({required bool start}) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: start ? startTime : endTime,
    );
    if (selected == null) return;
    setState(() {
      if (start) {
        startTime = selected;
        if (!_at(endTime).isAfter(_at(startTime))) {
          final end = _at(startTime).add(const Duration(hours: 1));
          endTime = TimeOfDay.fromDateTime(end);
        }
      } else {
        endTime = selected;
      }
    });
  }

  Future<void> _save() async {
    if (saving || titleController.text.trim().isEmpty) return;
    final start = _at(startTime);
    final end = _at(endTime);
    if (!end.isAfter(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La fin doit être après le début.')),
      );
      return;
    }
    setState(() => saving = true);
    try {
      await widget.onSave(
        title: titleController.text,
        startAt: start,
        endAt: end,
        description: descriptionController.text,
        location: locationController.text,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de créer l’événement.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nouvel événement',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: titleController,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Titre',
              prefixIcon: Icon(Icons.event_outlined),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(DateFormat.yMMMd('fr_FR').format(date)),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickTime(start: true),
                icon: const Icon(Icons.schedule),
                label: Text('Début ${startTime.format(context)}'),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickTime(start: false),
                icon: const Icon(Icons.schedule_outlined),
                label: Text('Fin ${endTime.format(context)}'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: locationController,
            decoration: const InputDecoration(
              labelText: 'Lieu (facultatif)',
              prefixIcon: Icon(Icons.place_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notes (facultatives)',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: saving ? null : _save,
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: const Text('Créer l’événement'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanningTray extends ConsumerWidget {
  const _PlanningTray({required this.tasks});
  final List<LocalTask> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DragTarget<LocalTask>(
      onAcceptWithDetails: (details) =>
          ref.read(taskRepositoryProvider).moveToInbox(details.data.id),
      builder: (context, candidates, _) => AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 82,
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.page,
          vertical: 8,
        ),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: candidates.isEmpty
              ? Theme.of(context).colorScheme.surfaceContainerLow
              : Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.inbox_outlined),
            const SizedBox(width: 8),
            if (tasks.isEmpty)
              const Expanded(
                child: Text('Déposez ici pour remettre une tâche dans l’Inbox'),
              )
            else
              Expanded(
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: tasks.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) =>
                      LongPressDraggable<LocalTask>(
                        data: tasks[index],
                        feedback: _DragFeedback(title: tasks[index].title),
                        child: Chip(
                          avatar: const Icon(Icons.drag_indicator, size: 18),
                          label: Text(tasks[index].title),
                        ),
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DayTimeline extends StatelessWidget {
  const _DayTimeline({
    required this.date,
    required this.events,
    required this.tasks,
    required this.repository,
  });

  final DateTime date;
  final List<LocalEvent> events;
  final List<LocalTask> tasks;
  final TaskRepository repository;
  static const hourHeight = 72.0;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        12,
        AppSpacing.page,
        32,
      ),
      child: SizedBox(
        height: hourHeight * 24,
        child: Builder(
          builder: (targetContext) => DragTarget<LocalTask>(
            onAcceptWithDetails: (details) {
              final box = targetContext.findRenderObject()! as RenderBox;
              final local = box.globalToLocal(details.offset);
              final rawMinutes = (local.dy / hourHeight * 60).round();
              final snappedMinutes = ((rawMinutes / 15).round() * 15).clamp(
                0,
                23 * 60 + 45,
              );
              final start = DateTime(
                date.year,
                date.month,
                date.day,
              ).add(Duration(minutes: snappedMinutes));
              repository.schedule(
                id: details.data.id,
                start: start,
                durationMinutes: details.data.estimatedDurationMinutes ?? 30,
              );
            },
            builder: (context, candidates, _) => Stack(
              children: [
                if (candidates.isNotEmpty)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.06),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                for (var hour = 0; hour < 24; hour++) ...[
                  Positioned(
                    top: hour * hourHeight,
                    left: 0,
                    width: 52,
                    child: Text('${hour.toString().padLeft(2, '0')}:00'),
                  ),
                  Positioned(
                    top: hour * hourHeight + 10,
                    left: 60,
                    right: 0,
                    child: const Divider(height: 1),
                  ),
                ],
                ...events.map((event) => _eventBlock(context, event)),
                ...tasks
                    .where(
                      (task) =>
                          task.scheduledStartAt != null &&
                          task.scheduledEndAt != null,
                    )
                    .map((task) => _taskBlock(context, task)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _eventBlock(BuildContext context, LocalEvent event) {
    return _positioned(
      start: event.startAt,
      end: event.endAt,
      child: _CalendarBlock(
        title: event.title,
        color: Theme.of(context).colorScheme.primaryContainer,
        icon: Icons.event,
      ),
    );
  }

  Widget _taskBlock(BuildContext context, LocalTask task) {
    final start = task.scheduledStartAt!;
    final end = task.scheduledEndAt!;
    return _positioned(
      start: start,
      end: end,
      child: LongPressDraggable<LocalTask>(
        data: task,
        feedback: _DragFeedback(title: task.title),
        childWhenDragging: const SizedBox.shrink(),
        child: _ResizableTaskBlock(
          task: task,
          color: Theme.of(context).colorScheme.tertiaryContainer,
          onComplete: () => repository.markCompleted(task.id),
          onResize: (minutes) => repository.schedule(
            id: task.id,
            start: start,
            durationMinutes: minutes,
          ),
        ),
      ),
    );
  }

  Widget _positioned({
    required DateTime start,
    required DateTime end,
    required Widget child,
  }) {
    final localStart = start.toLocal();
    final minutes = localStart.hour * 60 + localStart.minute;
    final duration = end.difference(start).inMinutes.clamp(20, 24 * 60);
    return Positioned(
      top: minutes / 60 * hourHeight,
      left: 68,
      right: 8,
      height: duration / 60 * hourHeight,
      child: child,
    );
  }
}

class _CalendarBlock extends StatelessWidget {
  const _CalendarBlock({
    required this.title,
    required this.color,
    required this.icon,
  });
  final String title;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResizableTaskBlock extends StatefulWidget {
  const _ResizableTaskBlock({
    required this.task,
    required this.color,
    required this.onComplete,
    required this.onResize,
  });
  final LocalTask task;
  final Color color;
  final VoidCallback onComplete;
  final ValueChanged<int> onResize;

  @override
  State<_ResizableTaskBlock> createState() => _ResizableTaskBlockState();
}

class _ResizableTaskBlockState extends State<_ResizableTaskBlock> {
  double dragDelta = 0;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: widget.color,
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 42, 12),
              child: Text(
                widget.task.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Positioned(
            right: 2,
            top: 0,
            child: IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Terminer',
              onPressed: widget.onComplete,
              icon: const Icon(Icons.check_circle_outline, size: 20),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 14,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: (details) => dragDelta += details.delta.dy,
              onVerticalDragEnd: (_) {
                final current = widget.task.scheduledEndAt!
                    .difference(widget.task.scheduledStartAt!)
                    .inMinutes;
                final resized =
                    ((current + dragDelta / _DayTimeline.hourHeight * 60) / 15)
                        .round() *
                    15;
                widget.onResize(resized.clamp(15, 12 * 60));
                dragDelta = 0;
              },
              child: const Center(child: Icon(Icons.drag_handle, size: 18)),
            ),
          ),
        ],
      ),
    );
  }
}

class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(padding: const EdgeInsets.all(14), child: Text(title)),
    );
  }
}
