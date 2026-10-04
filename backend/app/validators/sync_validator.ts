import vine from '@vinejs/vine'

const operationTypes = ['create', 'update', 'delete'] as const
const entityTypes = ['project', 'task', 'event', 'routine', 'calendar_source'] as const

export const syncPushValidator = vine.compile(
  vine.object({
    operations: vine
      .array(
        vine.object({
          id: vine.string().uuid(),
          operationType: vine.enum(operationTypes),
          entityType: vine.enum(entityTypes),
          entityId: vine.string().uuid(),
          payload: vine.record(vine.any()),
          createdAt: vine.date({ formats: { utc: true } }),
        })
      )
      .maxLength(100),
  })
)

export const syncPullValidator = vine.compile(
  vine.object({
    since: vine.date({ formats: { utc: true } }).optional(),
  })
)
