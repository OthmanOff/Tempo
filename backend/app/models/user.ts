import hash from '@adonisjs/core/services/hash'
import { compose } from '@adonisjs/core/helpers'
import { DbAccessTokensProvider } from '@adonisjs/auth/access_tokens'
import { withAuthFinder } from '@adonisjs/auth/mixins/lucid'
import { column, hasMany } from '@adonisjs/lucid/orm'
import type { HasMany } from '@adonisjs/lucid/types/relations'
import BaseSyncModel from '#models/base_sync_model'
import CalendarSource from '#models/calendar_source'
import Event from '#models/event'
import Project from '#models/project'
import Routine from '#models/routine'
import Task from '#models/task'

const AuthFinder = withAuthFinder(() => hash.use('scrypt'), {
  uids: ['email'],
  passwordColumnName: 'passwordHash',
})

export default class User extends compose(BaseSyncModel, AuthFinder) {
  @column()
  declare email: string

  @column({ serializeAs: null })
  declare passwordHash: string

  @column()
  declare name: string

  @column()
  declare timezone: string

  @hasMany(() => Project)
  declare projects: HasMany<typeof Project>

  @hasMany(() => Task)
  declare tasks: HasMany<typeof Task>

  @hasMany(() => Event)
  declare events: HasMany<typeof Event>

  @hasMany(() => Routine)
  declare routines: HasMany<typeof Routine>

  @hasMany(() => CalendarSource)
  declare calendarSources: HasMany<typeof CalendarSource>

  static accessTokens = DbAccessTokensProvider.forModel(User)
}
