import 'package:drift/drift.dart';

abstract class SyncTable extends Table {
  TextColumn get id => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('LocalUser')
class Users extends SyncTable {
  TextColumn get email => text().withLength(max: 254).unique()();
  TextColumn get name => text()();
  TextColumn get timezone =>
      text().withDefault(const Constant('Europe/Paris'))();
}

@DataClassName('LocalProject')
class Projects extends SyncTable {
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get name => text().withLength(max: 160)();
  TextColumn get description => text().nullable()();
  TextColumn get icon => text().nullable()();
  TextColumn get color => text().nullable()();
  DateTimeColumn get archivedAt => dateTime().nullable()();
}

@DataClassName('LocalCalendarSource')
class CalendarSources extends SyncTable {
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get name => text().withLength(max: 160)();
  TextColumn get type => text()();
  TextColumn get url => text().nullable()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
}

@DataClassName('LocalTask')
class Tasks extends SyncTable {
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get projectId => text().nullable().references(Projects, #id)();
  TextColumn get parentTaskId => text().nullable().references(Tasks, #id)();
  TextColumn get title => text().withLength(max: 500)();
  TextColumn get description => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('inbox'))();
  TextColumn get priority => text().withDefault(const Constant('none'))();
  IntColumn get estimatedDurationMinutes => integer().nullable()();
  DateTimeColumn get dueAt => dateTime().nullable()();
  DateTimeColumn get scheduledStartAt => dateTime().nullable()();
  DateTimeColumn get scheduledEndAt => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

@DataClassName('LocalEvent')
class Events extends SyncTable {
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get projectId => text().nullable().references(Projects, #id)();
  TextColumn get calendarSourceId =>
      text().nullable().references(CalendarSources, #id)();
  TextColumn get title => text().withLength(max: 500)();
  TextColumn get description => text().nullable()();
  TextColumn get location => text().nullable()();
  DateTimeColumn get startAt => dateTime()();
  DateTimeColumn get endAt => dateTime()();
  BoolColumn get allDay => boolean().withDefault(const Constant(false))();
  TextColumn get recurrenceRule => text().nullable()();
  TextColumn get source => text().withDefault(const Constant('local'))();
  TextColumn get externalId => text().nullable()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {calendarSourceId, externalId},
  ];
}

@DataClassName('LocalRoutine')
class Routines extends SyncTable {
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get projectId => text().nullable().references(Projects, #id)();
  TextColumn get name => text().withLength(max: 160)();
  TextColumn get recurrenceRule => text()();
  IntColumn get preferredDurationMinutes => integer()();
  TextColumn get preferredStartTime => text().nullable()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
}

@DataClassName('PendingOperation')
class PendingOperations extends Table {
  TextColumn get id => text()();
  TextColumn get operationType => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get payload => text()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('SyncMetadataEntry')
class SyncMetadata extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
