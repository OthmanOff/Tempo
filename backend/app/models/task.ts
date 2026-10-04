import { DateTime } from 'luxon'
import { belongsTo, column, hasMany } from '@adonisjs/lucid/orm'
import type { BelongsTo, HasMany } from '@adonisjs/lucid/types/relations'
import BaseSyncModel from '#models/base_sync_model'
import Project from '#models/project'
import User from '#models/user'

export const taskStatuses = [
  'inbox',
  'todo',
  'scheduled',
  'in_progress',
  'completed',
  'cancelled',
] as const
export type TaskStatus = (typeof taskStatuses)[number]

export const taskPriorities = ['none', 'low', 'medium', 'high', 'urgent'] as const
export type TaskPriority = (typeof taskPriorities)[number]

export default class Task extends BaseSyncModel {
  @column()
  declare userId: string

  @column()
  declare projectId: string | null

  @column()
  declare parentTaskId: string | null

  @column()
  declare title: string

  @column()
  declare description: string | null

  @column()
  declare status: TaskStatus

  @column()
  declare priority: TaskPriority

  @column()
  declare estimatedDurationMinutes: number | null

  @column.dateTime()
  declare dueAt: DateTime | null

  @column.dateTime()
  declare scheduledStartAt: DateTime | null

  @column.dateTime()
  declare scheduledEndAt: DateTime | null

  @column.dateTime()
  declare completedAt: DateTime | null

  @column({ columnName: 'sort_order' })
  declare order: number

  @belongsTo(() => User)
  declare user: BelongsTo<typeof User>

  @belongsTo(() => Project)
  declare project: BelongsTo<typeof Project>

  @belongsTo(() => Task, { foreignKey: 'parentTaskId' })
  declare parentTask: BelongsTo<typeof Task>

  @hasMany(() => Task, { foreignKey: 'parentTaskId' })
  declare subtasks: HasMany<typeof Task>
}
