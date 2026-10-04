import { DateTime } from 'luxon'
import { Exception } from '@adonisjs/core/exceptions'
import Event, { type EventSource } from '#models/event'

export interface EventInput {
  id?: string
  title?: string
  description?: string | null
  location?: string | null
  startAt?: DateTime
  endAt?: DateTime
  allDay?: boolean
  projectId?: string | null
  calendarSourceId?: string | null
  recurrenceRule?: string | null
  source?: EventSource
  externalId?: string | null
}

export default class CalendarService {
  async listRange(userId: string, from: DateTime, to: DateTime) {
    if (to <= from) {
      throw new Exception('The end of the range must be after its start', {
        status: 422,
        code: 'E_INVALID_DATE_RANGE',
      })
    }
    return Event.query()
      .where('userId', userId)
      .whereNull('deletedAt')
      .where('startAt', '<', to.toSQL()!)
      .where('endAt', '>', from.toSQL()!)
      .orderBy('startAt')
  }

  async find(userId: string, id: string) {
    return Event.query()
      .where('userId', userId)
      .where('id', id)
      .whereNull('deletedAt')
      .firstOrFail()
  }

  async create(userId: string, input: EventInput) {
    this.assertDates(input.startAt, input.endAt)
    return Event.create({ userId, allDay: false, source: 'local', ...input })
  }

  async update(userId: string, id: string, input: EventInput) {
    const event = await this.find(userId, id)
    this.assertDates(input.startAt ?? event.startAt, input.endAt ?? event.endAt)
    event.merge(input)
    await event.save()
    return event
  }

  async remove(userId: string, id: string) {
    const event = await this.find(userId, id)
    event.deletedAt = DateTime.utc()
    await event.save()
  }

  private assertDates(startAt?: DateTime, endAt?: DateTime) {
    if (!startAt || !endAt || endAt <= startAt) {
      throw new Exception('The event end must be after its start', {
        status: 422,
        code: 'E_INVALID_EVENT_DATES',
      })
    }
  }
}
