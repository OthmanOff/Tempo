import { DateTime } from 'luxon'
import type { HttpContext } from '@adonisjs/core/http'
import SyncService from '#services/sync_service'
import { syncPullValidator, syncPushValidator } from '#validators/sync_validator'

export default class SyncController {
  private service = new SyncService()

  async push({ auth, request }: HttpContext) {
    const payload = await request.validateUsing(syncPushValidator)
    return this.service.push(auth.user!.id, payload.operations)
  }

  async pull({ auth, request }: HttpContext) {
    const query = await syncPullValidator.validate(request.qs())
    return this.service.pull(
      auth.user!.id,
      query.since ? DateTime.fromJSDate(query.since).toUTC() : undefined
    )
  }
}
