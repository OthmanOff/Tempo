import vine from '@vinejs/vine'
import { taskPriorities, taskStatuses } from '#models/task'

const optionalTaskFields = {
  description: vine.string().trim().nullable().optional(),
  projectId: vine.string().uuid().nullable().optional(),
  parentTaskId: vine.string().uuid().nullable().optional(),
  priority: vine.enum(taskPriorities).optional(),
  estimatedDurationMinutes: vine.number().positive().withoutDecimals().nullable().optional(),
  dueAt: vine
    .date({ formats: { utc: true } })
    .nullable()
    .optional(),
  scheduledStartAt: vine
    .date({ formats: { utc: true } })
    .nullable()
    .optional(),
  scheduledEndAt: vine
    .date({ formats: { utc: true } })
    .nullable()
    .optional(),
  order: vine.number().withoutDecimals().min(0).optional(),
}

export const createTaskValidator = vine.compile(
  vine.object({
    id: vine.string().uuid().optional(),
    title: vine.string().trim().minLength(1).maxLength(500),
    status: vine.enum(taskStatuses).optional(),
    ...optionalTaskFields,
  })
)

export const updateTaskValidator = vine.compile(
  vine.object({
    title: vine.string().trim().minLength(1).maxLength(500).optional(),
    status: vine.enum(taskStatuses).optional(),
    completedAt: vine
      .date({ formats: { utc: true } })
      .nullable()
      .optional(),
    ...optionalTaskFields,
  })
)
