import { DateTime } from 'luxon'
import type { HttpContext } from '@adonisjs/core/http'
import CalendarService, { type EventInput } from '#services/calendar_service'
import {
  createEventValidator,
  eventRangeValidator,
  updateEventValidator,
} from '#validators/event_validator'

export default class EventsController {
  private service = new CalendarService()

  async index({ auth, request }: HttpContext) {
    const range = await eventRangeValidator.validate(request.qs())
    return this.service.listRange(
      auth.user!.id,
      DateTime.fromJSDate(range.from).toUTC(),
      DateTime.fromJSDate(range.to).toUTC()
    )
  }

  async show({ auth, params }: HttpContext) {
    return this.service.find(auth.user!.id, params.id)
  }

  async store({ auth, request, response }: HttpContext) {
    const payload = await request.validateUsing(createEventValidator)
    return response.created(await this.service.create(auth.user!.id, this.mapDates(payload)))
  }

  async update({ auth, params, request }: HttpContext) {
    const payload = await request.validateUsing(updateEventValidator)
    return this.service.update(auth.user!.id, params.id, this.mapDates(payload))
  }

  async destroy({ auth, params, response }: HttpContext) {
    await this.service.remove(auth.user!.id, params.id)
    return response.noContent()
  }

  private mapDates(payload: Record<string, unknown>): EventInput {
    return {
      ...payload,
      startAt: payload.startAt ? DateTime.fromJSDate(payload.startAt as Date).toUTC() : undefined,
      endAt: payload.endAt ? DateTime.fromJSDate(payload.endAt as Date).toUTC() : undefined,
    } as EventInput
  }
}
