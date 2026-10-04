import { DateTime } from 'luxon'
import type { HttpContext } from '@adonisjs/core/http'
import Routine from '#models/routine'
import { createRoutineValidator, updateRoutineValidator } from '#validators/routine_validator'

export default class RoutinesController {
  async index({ auth }: HttpContext) {
    return Routine.query().where('userId', auth.user!.id).whereNull('deletedAt').orderBy('name')
  }

  async store({ auth, request, response }: HttpContext) {
    const payload = await request.validateUsing(createRoutineValidator)
    return response.created(
      await Routine.create({ userId: auth.user!.id, enabled: true, ...payload })
    )
  }

  async update({ auth, params, request }: HttpContext) {
    const routine = await this.find(auth.user!.id, params.id)
    routine.merge(await request.validateUsing(updateRoutineValidator))
    await routine.save()
    return routine
  }

  async destroy({ auth, params, response }: HttpContext) {
    const routine = await this.find(auth.user!.id, params.id)
    routine.deletedAt = DateTime.utc()
    await routine.save()
    return response.noContent()
  }

  private find(userId: string, id: string) {
    return Routine.query()
      .where('userId', userId)
      .where('id', id)
      .whereNull('deletedAt')
      .firstOrFail()
  }
}
