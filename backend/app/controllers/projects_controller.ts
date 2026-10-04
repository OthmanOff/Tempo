import { DateTime } from 'luxon'
import type { HttpContext } from '@adonisjs/core/http'
import Project from '#models/project'
import { createProjectValidator, updateProjectValidator } from '#validators/project_validator'

export default class ProjectsController {
  async index({ auth }: HttpContext) {
    return Project.query().where('userId', auth.user!.id).whereNull('deletedAt').orderBy('name')
  }

  async show({ auth, params }: HttpContext) {
    return this.find(auth.user!.id, params.id)
  }

  async store({ auth, request, response }: HttpContext) {
    const payload = await request.validateUsing(createProjectValidator)
    return response.created(await Project.create({ userId: auth.user!.id, ...payload }))
  }

  async update({ auth, params, request }: HttpContext) {
    const project = await this.find(auth.user!.id, params.id)
    const payload = await request.validateUsing(updateProjectValidator)
    project.merge({
      ...payload,
      archivedAt: payload.archivedAt
        ? DateTime.fromJSDate(payload.archivedAt).toUTC()
        : payload.archivedAt,
    })
    await project.save()
    return project
  }

  async destroy({ auth, params, response }: HttpContext) {
    const project = await this.find(auth.user!.id, params.id)
    project.deletedAt = DateTime.utc()
    await project.save()
    return response.noContent()
  }

  private find(userId: string, id: string) {
    return Project.query()
      .where('userId', userId)
      .where('id', id)
      .whereNull('deletedAt')
      .firstOrFail()
  }
}
