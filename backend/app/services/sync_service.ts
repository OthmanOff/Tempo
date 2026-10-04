import { DateTime } from 'luxon'
import db from '@adonisjs/lucid/services/db'
import CalendarSource from '#models/calendar_source'
import Event from '#models/event'
import Project from '#models/project'
import Routine from '#models/routine'
import Task from '#models/task'

type EntityType = 'project' | 'task' | 'event' | 'routine' | 'calendar_source'
type OperationType = 'create' | 'update' | 'delete'

export interface PushOperation {
  id: string
  operationType: OperationType
  entityType: EntityType
  entityId: string
  payload: Record<string, unknown>
  createdAt: Date
}

const modelByEntity = {
  project: Project,
  task: Task,
  event: Event,
  routine: Routine,
  calendar_source: CalendarSource,
} as const

const dateFields = new Set([
  'createdAt',
  'updatedAt',
  'deletedAt',
  'archivedAt',
  'dueAt',
  'scheduledStartAt',
  'scheduledEndAt',
  'completedAt',
  'startAt',
  'endAt',
  'lastSyncedAt',
])

export default class SyncService {
  async push(userId: string, operations: PushOperation[]) {
    const accepted: string[] = []

    for (const operation of operations) {
      await db.transaction(async (trx) => {
        const alreadyProcessed = await trx
          .from('sync_operations')
          .where('id', operation.id)
          .where('user_id', userId)
          .first()
        if (alreadyProcessed) {
          accepted.push(operation.id)
          return
        }

        const Model = modelByEntity[operation.entityType]
        const existing = await Model.query({ client: trx })
          .where('id', operation.entityId)
          .where('userId', userId)
          .first()

        if (operation.operationType === 'delete') {
          if (existing) {
            existing.deletedAt = DateTime.utc()
            await existing.save()
          }
        } else {
          const payload = this.normalizePayload(operation.payload)
          delete payload.userId
          delete payload.id
          const incomingUpdatedAt = payload.updatedAt as DateTime | undefined
          if (!existing) {
            await Model.create({ ...payload, id: operation.entityId, userId }, { client: trx })
          } else if (!incomingUpdatedAt || incomingUpdatedAt >= existing.updatedAt) {
            existing.merge(payload)
            await existing.save()
          }
        }

        await trx.table('sync_operations').insert({
          id: operation.id,
          user_id: userId,
          entity_type: operation.entityType,
          entity_id: operation.entityId,
          processed_at: DateTime.utc().toSQL(),
        })
        accepted.push(operation.id)
      })
    }

    return { accepted }
  }

  async pull(userId: string, since?: DateTime) {
    const cursor = DateTime.utc()
    const changes: Array<{ entityType: EntityType; data: Record<string, unknown> }> = []

    for (const [entityType, Model] of Object.entries(modelByEntity) as [
      EntityType,
      (typeof modelByEntity)[EntityType],
    ][]) {
      const query = Model.query().where('userId', userId).where('updatedAt', '<=', cursor.toSQL()!)
      if (since) query.where('updatedAt', '>', since.toSQL()!)
      const rows = await query.orderBy('updatedAt')
      for (const row of rows) {
        changes.push({ entityType, data: row.serialize() })
      }
    }

    return { cursor: cursor.toISO(), changes }
  }

  private normalizePayload(payload: Record<string, unknown>) {
    return Object.fromEntries(
      Object.entries(payload).map(([key, value]) => [
        key,
        dateFields.has(key) && typeof value === 'string' ? DateTime.fromISO(value).toUTC() : value,
      ])
    )
  }
}
