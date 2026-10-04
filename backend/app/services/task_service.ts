import { DateTime } from 'luxon'
import { Exception } from '@adonisjs/core/exceptions'
import Task, { type TaskPriority, type TaskStatus } from '#models/task'

export interface TaskFilters {
  status?: TaskStatus
  priority?: TaskPriority
  projectId?: string
  from?: DateTime
  to?: DateTime
  withoutDate?: boolean
}

export interface TaskInput {
  id?: string
  title?: string
  description?: string | null
  projectId?: string | null
  parentTaskId?: string | null
  status?: TaskStatus
  priority?: TaskPriority
  estimatedDurationMinutes?: number | null
  dueAt?: DateTime | null
  scheduledStartAt?: DateTime | null
  scheduledEndAt?: DateTime | null
  completedAt?: DateTime | null
  order?: number
}

export default class TaskService {
  async list(userId: string, filters: TaskFilters = {}) {
    const query = Task.query().where('userId', userId).whereNull('deletedAt').orderBy('sortOrder')

    if (filters.status) query.where('status', filters.status)
    if (filters.priority) query.where('priority', filters.priority)
    if (filters.projectId) query.where('projectId', filters.projectId)
    if (filters.withoutDate) {
      query.whereNull('dueAt').whereNull('scheduledStartAt')
    }
    if (filters.from) query.where('scheduledStartAt', '>=', filters.from.toSQL()!)
    if (filters.to) query.where('scheduledStartAt', '<', filters.to.toSQL()!)

    return query
  }

  async find(userId: string, id: string) {
    return Task.query().where('userId', userId).where('id', id).whereNull('deletedAt').firstOrFail()
  }

  async create(userId: string, input: TaskInput) {
    const values = this.normalize(input)
    this.assertSchedule(values)
    return Task.create({ userId, status: 'inbox', priority: 'none', order: 0, ...values })
  }

  async update(userId: string, id: string, input: TaskInput) {
    const task = await this.find(userId, id)
    const values = this.normalize(input)
    this.assertSchedule({
      scheduledStartAt: values.scheduledStartAt ?? task.scheduledStartAt,
      scheduledEndAt: values.scheduledEndAt ?? task.scheduledEndAt,
      status: values.status ?? task.status,
    })
    task.merge(values)
    await task.save()
    return task
  }

  async remove(userId: string, id: string) {
    const task = await this.find(userId, id)
    task.deletedAt = DateTime.utc()
    await task.save()
  }

  private normalize(input: TaskInput): TaskInput {
    const values = { ...input }
    if (values.scheduledStartAt && !values.scheduledEndAt && values.estimatedDurationMinutes) {
      values.scheduledEndAt = values.scheduledStartAt.plus({
        minutes: values.estimatedDurationMinutes,
      })
    }
    if (values.scheduledStartAt && values.scheduledEndAt && !values.status)
      values.status = 'scheduled'
    if (values.status === 'completed' && !values.completedAt) values.completedAt = DateTime.utc()
    if (values.status && values.status !== 'completed' && values.completedAt === undefined) {
      values.completedAt = null
    }
    return values
  }

  private assertSchedule(input: TaskInput) {
    const start = input.scheduledStartAt
    const end = input.scheduledEndAt
    const hasStart = start !== null && start !== undefined
    const hasEnd = end !== null && end !== undefined
    if (hasStart !== hasEnd) {
      throw new Exception('A scheduled task requires both a start and an end', {
        status: 422,
        code: 'E_INVALID_TASK_SCHEDULE',
      })
    }
    if (start && end && end <= start) {
      throw new Exception('The scheduled end must be after the start', {
        status: 422,
        code: 'E_INVALID_TASK_SCHEDULE',
      })
    }
  }
}
