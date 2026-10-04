import type { HttpContext } from '@adonisjs/core/http'
import hash from '@adonisjs/core/services/hash'
import User from '#models/user'
import { loginValidator, registerValidator } from '#validators/auth_validator'

export default class AuthController {
  async register({ request, response }: HttpContext) {
    const { name, email, password } = await request.validateUsing(registerValidator)
    const user = await User.create({
      name,
      email,
      passwordHash: await hash.make(password),
      timezone: 'Europe/Paris',
    })
    const token = await User.accessTokens.create(user)

    return response.created({ type: 'bearer', token: token.value!.release(), user })
  }

  async login({ request }: HttpContext) {
    const { email, password } = await request.validateUsing(loginValidator)
    const user = await User.verifyCredentials(email, password)
    const token = await User.accessTokens.create(user)

    return { type: 'bearer', token: token.value!.release(), user }
  }

  async me({ auth }: HttpContext) {
    return auth.getUserOrFail()
  }
}
