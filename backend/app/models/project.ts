import { DateTime } from 'luxon'
import { belongsTo, column, hasMany } from '@adonisjs/lucid/orm'
import type { BelongsTo, HasMany } from '@adonisjs/lucid/types/relations'
import BaseSyncModel from '#models/base_sync_model'
import Event from '#models/event'
import Routine from '#models/routine'
import Task from '#models/task'
import User from '#models/user'

export default class Project extends BaseSyncModel {
  @column()
  declare userId: string

  @column()
  declare name: string

  @column()
  declare description: string | null

  @column()
  declare icon: string | null

  @column()
  declare color: string | null

  @column.dateTime()
  declare archivedAt: DateTime | null

  @belongsTo(() => User)
  declare user: BelongsTo<typeof User>

  @hasMany(() => Task)
  declare tasks: HasMany<typeof Task>

  @hasMany(() => Event)
  declare events: HasMany<typeof Event>

  @hasMany(() => Routine)
  declare routines: HasMany<typeof Routine>
}
