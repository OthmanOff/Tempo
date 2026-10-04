import vine from '@vinejs/vine'
import { calendarSourceTypes } from '#models/calendar_source'

export const createCalendarSourceValidator = vine.compile(
  vine.object({
    id: vine.string().uuid().optional(),
    name: vine.string().trim().minLength(1).maxLength(160),
    type: vine.enum(calendarSourceTypes),
    url: vine.string().url().nullable().optional(),
    enabled: vine.boolean().optional(),
  })
)

export const updateCalendarSourceValidator = vine.compile(
  vine.object({
    name: vine.string().trim().minLength(1).maxLength(160).optional(),
    url: vine.string().url().nullable().optional(),
    enabled: vine.boolean().optional(),
  })
)

export const importIcsValidator = vine.compile(
  vine.object({
    name: vine.string().trim().minLength(1).maxLength(160),
    content: vine.string().minLength(1).maxLength(5_000_000),
  })
)
