import { DateTime } from 'luxon'
import { belongsTo, column } from '@adonisjs/lucid/orm'
import type { BelongsTo } from '@adonisjs/lucid/types/relations'
import BaseSyncModel from '#models/base_sync_model'
import CalendarSource from '#models/calendar_source'
import Project from '#models/project'
import User from '#models/user'

export const eventSources = ['local', 'ics', 'external'] as const
export type EventSource = (typeof eventSources)[number]

export default class Event extends BaseSyncModel {
  @column()
  declare userId: string

  @column()
  declare projectId: string | null

  @column()
  declare calendarSourceId: string | null

  @column()
  declare title: string

  @column()
  declare description: string | null

  @column()
  declare location: string | null

  @column.dateTime()
  declare startAt: DateTime

  @column.dateTime()
  declare endAt: DateTime

  @column()
  declare allDay: boolean

  @column()
  declare recurrenceRule: string | null

  @column()
  declare source: EventSource

  @column()
  declare externalId: string | null

  @belongsTo(() => User)
  declare user: BelongsTo<typeof User>

  @belongsTo(() => Project)
  declare project: BelongsTo<typeof Project>

  @belongsTo(() => CalendarSource)
  declare calendarSource: BelongsTo<typeof CalendarSource>
}
