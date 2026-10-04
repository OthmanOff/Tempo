import vine from '@vinejs/vine'

export const createRoutineValidator = vine.compile(
  vine.object({
    id: vine.string().uuid().optional(),
    name: vine.string().trim().minLength(1).maxLength(160),
    projectId: vine.string().uuid().nullable().optional(),
    recurrenceRule: vine.string().trim().minLength(1),
    preferredDurationMinutes: vine.number().positive().withoutDecimals(),
    preferredStartTime: vine
      .string()
      .regex(/^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$/)
      .nullable()
      .optional(),
    enabled: vine.boolean().optional(),
  })
)

export const updateRoutineValidator = vine.compile(
  vine.object({
    name: vine.string().trim().minLength(1).maxLength(160).optional(),
    projectId: vine.string().uuid().nullable().optional(),
    recurrenceRule: vine.string().trim().minLength(1).optional(),
    preferredDurationMinutes: vine.number().positive().withoutDecimals().optional(),
    preferredStartTime: vine
      .string()
      .regex(/^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$/)
      .nullable()
      .optional(),
    enabled: vine.boolean().optional(),
  })
)
