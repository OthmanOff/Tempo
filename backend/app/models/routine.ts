import { belongsTo, column } from '@adonisjs/lucid/orm'
import type { BelongsTo } from '@adonisjs/lucid/types/relations'
import BaseSyncModel from '#models/base_sync_model'
import Project from '#models/project'
import User from '#models/user'

export default class Routine extends BaseSyncModel {
  @column()
  declare userId: string

  @column()
  declare projectId: string | null

  @column()
  declare name: string

  @column()
  declare recurrenceRule: string

  @column()
  declare preferredDurationMinutes: number

  @column()
  declare preferredStartTime: string | null

  @column()
  declare enabled: boolean

  @belongsTo(() => User)
  declare user: BelongsTo<typeof User>

  @belongsTo(() => Project)
  declare project: BelongsTo<typeof Project>
}
