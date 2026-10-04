import { DateTime } from 'luxon'
import type { HttpContext } from '@adonisjs/core/http'
import CalendarSource from '#models/calendar_source'
import {
  createCalendarSourceValidator,
  importIcsValidator,
  updateCalendarSourceValidator,
} from '#validators/calendar_source_validator'
import IcsService from '#services/ics_service'

export default class CalendarSourcesController {
  private icsService = new IcsService()
  async index({ auth }: HttpContext) {
    return CalendarSource.query()
      .where('userId', auth.user!.id)
      .whereNull('deletedAt')
      .orderBy('name')
  }

  async store({ auth, request, response }: HttpContext) {
    const payload = await request.validateUsing(createCalendarSourceValidator)
    return response.created(
      await CalendarSource.create({ userId: auth.user!.id, enabled: true, ...payload })
    )
  }

  async update({ auth, params, request }: HttpContext) {
    const source = await this.find(auth.user!.id, params.id)
    source.merge(await request.validateUsing(updateCalendarSourceValidator))
    await source.save()
    return source
  }

  async destroy({ auth, params, response }: HttpContext) {
    const source = await this.find(auth.user!.id, params.id)
    source.deletedAt = DateTime.utc()
    await source.save()
    return response.noContent()
  }

  async importFile({ auth, request, response }: HttpContext) {
    const payload = await request.validateUsing(importIcsValidator)
    const source = await CalendarSource.create({
      userId: auth.user!.id,
      name: payload.name,
      type: 'ics_file',
      enabled: true,
    })
    const result = await this.icsService.importContent(auth.user!.id, source, payload.content)
    return response.created({ source, ...result })
  }

  async sync({ auth, params }: HttpContext) {
    const source = await this.find(auth.user!.id, params.id)
    return this.icsService.syncUrl(auth.user!.id, source)
  }

  private find(userId: string, id: string) {
    return CalendarSource.query()
      .where('userId', userId)
      .where('id', id)
      .whereNull('deletedAt')
      .firstOrFail()
  }
}
