import { DateTime } from 'luxon'
import type { HttpContext } from '@adonisjs/core/http'
import type { TaskPriority, TaskStatus } from '#models/task'
import TaskService, { type TaskInput } from '#services/task_service'
import { createTaskValidator, updateTaskValidator } from '#validators/task_validator'

export default class TasksController {
  private service = new TaskService()

  async index({ auth, request }: HttpContext) {
    const query = request.qs()
    return this.service.list(auth.user!.id, {
      status: query.status as TaskStatus | undefined,
      priority: query.priority as TaskPriority | undefined,
      projectId: query.projectId,
      withoutDate: query.withoutDate === 'true',
      from: query.from ? DateTime.fromISO(query.from, { setZone: true }) : undefined,
      to: query.to ? DateTime.fromISO(query.to, { setZone: true }) : undefined,
    })
  }

  async show({ auth, params }: HttpContext) {
    return this.service.find(auth.user!.id, params.id)
  }

  async store({ auth, request, response }: HttpContext) {
    const payload = await request.validateUsing(createTaskValidator)
    return response.created(await this.service.create(auth.user!.id, this.mapDates(payload)))
  }

  async update({ auth, params, request }: HttpContext) {
    const payload = await request.validateUsing(updateTaskValidator)
    return this.service.update(auth.user!.id, params.id, this.mapDates(payload))
  }

  async destroy({ auth, params, response }: HttpContext) {
    await this.service.remove(auth.user!.id, params.id)
    return response.noContent()
  }

  private mapDates(payload: Record<string, unknown>): TaskInput {
    return {
      ...payload,
      dueAt: payload.dueAt
        ? DateTime.fromJSDate(payload.dueAt as Date).toUTC()
        : (payload.dueAt as null),
      scheduledStartAt: payload.scheduledStartAt
        ? DateTime.fromJSDate(payload.scheduledStartAt as Date).toUTC()
        : (payload.scheduledStartAt as null),
      scheduledEndAt: payload.scheduledEndAt
        ? DateTime.fromJSDate(payload.scheduledEndAt as Date).toUTC()
        : (payload.scheduledEndAt as null),
      completedAt: payload.completedAt
        ? DateTime.fromJSDate(payload.completedAt as Date).toUTC()
        : (payload.completedAt as null),
    } as TaskInput
  }
}
