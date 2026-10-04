import vine from '@vinejs/vine'

const fields = {
  name: vine.string().trim().minLength(1).maxLength(160),
  description: vine.string().trim().nullable().optional(),
  icon: vine.string().trim().maxLength(80).nullable().optional(),
  color: vine.string().trim().maxLength(32).nullable().optional(),
}

export const createProjectValidator = vine.compile(vine.object(fields))
export const updateProjectValidator = vine.compile(
  vine.object({
    name: fields.name.optional(),
    description: fields.description,
    icon: fields.icon,
    color: fields.color,
    archivedAt: vine
      .date({ formats: { utc: true } })
      .nullable()
      .optional(),
  })
)
