import vine from '@vinejs/vine'
import { eventSources } from '#models/event'

const optionalEventFields = {
  description: vine.string().trim().nullable().optional(),
  location: vine.string().trim().maxLength(500).nullable().optional(),
  projectId: vine.string().uuid().nullable().optional(),
  calendarSourceId: vine.string().uuid().nullable().optional(),
  allDay: vine.boolean().optional(),
  recurrenceRule: vine.string().trim().nullable().optional(),
  source: vine.enum(eventSources).optional(),
  externalId: vine.string().trim().maxLength(512).nullable().optional(),
}

export const createEventValidator = vine.compile(
  vine.object({
    id: vine.string().uuid().optional(),
    title: vine.string().trim().minLength(1).maxLength(500),
    startAt: vine.date({ formats: { utc: true } }),
    endAt: vine.date({ formats: { utc: true } }),
    ...optionalEventFields,
  })
)

export const updateEventValidator = vine.compile(
  vine.object({
    title: vine.string().trim().minLength(1).maxLength(500).optional(),
    startAt: vine.date({ formats: { utc: true } }).optional(),
    endAt: vine.date({ formats: { utc: true } }).optional(),
    ...optionalEventFields,
  })
)

export const eventRangeValidator = vine.compile(
  vine.object({
    from: vine.date({ formats: { utc: true } }),
    to: vine.date({ formats: { utc: true } }),
  })
)
