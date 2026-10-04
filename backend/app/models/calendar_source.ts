import { DateTime } from 'luxon'
import { belongsTo, column, hasMany } from '@adonisjs/lucid/orm'
import type { BelongsTo, HasMany } from '@adonisjs/lucid/types/relations'
import BaseSyncModel from '#models/base_sync_model'
import Event from '#models/event'
import User from '#models/user'

export const calendarSourceTypes = ['local', 'ics_url', 'ics_file'] as const
export type CalendarSourceType = (typeof calendarSourceTypes)[number]

export default class CalendarSource extends BaseSyncModel {
  @column()
  declare userId: string

  @column()
  declare name: string

  @column()
  declare type: CalendarSourceType

  @column()
  declare url: string | null

  @column()
  declare enabled: boolean

  @column.dateTime()
  declare lastSyncedAt: DateTime | null

  @belongsTo(() => User)
  declare user: BelongsTo<typeof User>

  @hasMany(() => Event)
  declare events: HasMany<typeof Event>
}
