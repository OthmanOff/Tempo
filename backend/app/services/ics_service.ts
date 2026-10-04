import { DateTime } from 'luxon'
import ICAL from 'ical.js'
import { Exception } from '@adonisjs/core/exceptions'
import CalendarSource from '#models/calendar_source'
import Event from '#models/event'

export interface ParsedIcsEvent {
  uid: string
  title: string
  description: string | null
  location: string | null
  startAt: DateTime
  endAt: DateTime
  allDay: boolean
  recurrenceRule: string | null
}

export default class IcsService {
  parse(content: string): ParsedIcsEvent[] {
    let calendar: ICAL.Component
    try {
      calendar = new ICAL.Component(ICAL.parse(content))
    } catch {
      throw new Exception('Invalid iCalendar content', { status: 422, code: 'E_INVALID_ICS' })
    }

    return calendar.getAllSubcomponents('vevent').map((component) => {
      const event = new ICAL.Event(component)
      if (!event.uid || !event.startDate || !event.endDate) {
        throw new Exception('Every VEVENT requires UID, DTSTART and DTEND', {
          status: 422,
          code: 'E_INVALID_ICS_EVENT',
        })
      }
      const rrule = component.getFirstProperty('rrule')?.toICALString()
      return {
        uid: event.uid,
        title: event.summary || 'Sans titre',
        description: event.description || null,
        location: event.location || null,
        startAt: DateTime.fromJSDate(event.startDate.toJSDate()).toUTC(),
        endAt: DateTime.fromJSDate(event.endDate.toJSDate()).toUTC(),
        allDay: event.startDate.isDate,
        recurrenceRule: rrule ? rrule.replace(/^RRULE:/, '') : null,
      }
    })
  }

  async importContent(userId: string, source: CalendarSource, content: string) {
    const parsed = this.parse(content)
    for (const item of parsed) {
      const existing = await Event.query()
        .where('userId', userId)
        .where('calendarSourceId', source.id)
        .where('externalId', item.uid)
        .first()
      const values = {
        ...item,
        userId,
        calendarSourceId: source.id,
        source: 'ics' as const,
        deletedAt: null,
      }
      if (existing) {
        existing.merge(values)
        await existing.save()
      } else {
        await Event.create(values)
      }
    }
    source.lastSyncedAt = DateTime.utc()
    await source.save()
    return { imported: parsed.length }
  }

  async syncUrl(userId: string, source: CalendarSource) {
    if (source.type !== 'ics_url' || !source.url) {
      throw new Exception('This source is not an ICS URL subscription', {
        status: 422,
        code: 'E_INVALID_CALENDAR_SOURCE',
      })
    }
    const url = new URL(source.url)
    this.assertSafeRemoteUrl(url)
    const response = await fetch(url, { signal: AbortSignal.timeout(15_000) })
    if (!response.ok) {
      throw new Exception(`ICS server returned ${response.status}`, {
        status: 502,
        code: 'E_ICS_FETCH_FAILED',
      })
    }
    const declaredSize = Number(response.headers.get('content-length') ?? 0)
    if (declaredSize > 5_000_000) {
      throw new Exception('ICS feed exceeds 5 MB', { status: 413, code: 'E_ICS_TOO_LARGE' })
    }
    const content = await response.text()
    if (content.length > 5_000_000) {
      throw new Exception('ICS feed exceeds 5 MB', { status: 413, code: 'E_ICS_TOO_LARGE' })
    }
    return this.importContent(userId, source, content)
  }

  private assertSafeRemoteUrl(url: URL) {
    const host = url.hostname.toLowerCase()
    const privateAddress =
      host === 'localhost' ||
      host === '::1' ||
      /^127\./.test(host) ||
      /^10\./.test(host) ||
      /^192\.168\./.test(host) ||
      /^169\.254\./.test(host) ||
      /^172\.(1[6-9]|2\d|3[01])\./.test(host)
    if (!['http:', 'https:'].includes(url.protocol) || privateAddress) {
      throw new Exception('Unsafe ICS URL', { status: 422, code: 'E_UNSAFE_ICS_URL' })
    }
  }
}
