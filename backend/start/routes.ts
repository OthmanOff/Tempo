import router from '@adonisjs/core/services/router'
import { middleware } from '#start/kernel'

const AuthController = () => import('#controllers/auth_controller')
const CalendarSourcesController = () => import('#controllers/calendar_sources_controller')
const EventsController = () => import('#controllers/events_controller')
const ProjectsController = () => import('#controllers/projects_controller')
const RoutinesController = () => import('#controllers/routines_controller')
const TasksController = () => import('#controllers/tasks_controller')
const SyncController = () => import('#controllers/sync_controller')

router.get('/health', async () => ({ status: 'ok', service: 'agenda-api' }))

router
  .group(() => {
    router.post('/auth/login', [AuthController, 'login'])
    router.post('/auth/register', [AuthController, 'register'])

    router
      .group(() => {
        router.get('/me', [AuthController, 'me'])

        router.get('/projects', [ProjectsController, 'index'])
        router.post('/projects', [ProjectsController, 'store'])
        router.get('/projects/:id', [ProjectsController, 'show'])
        router.patch('/projects/:id', [ProjectsController, 'update'])
        router.delete('/projects/:id', [ProjectsController, 'destroy'])

        router.get('/tasks', [TasksController, 'index'])
        router.post('/tasks', [TasksController, 'store'])
        router.get('/tasks/:id', [TasksController, 'show'])
        router.patch('/tasks/:id', [TasksController, 'update'])
        router.delete('/tasks/:id', [TasksController, 'destroy'])

        router.get('/events', [EventsController, 'index'])
        router.post('/events', [EventsController, 'store'])
        router.get('/events/:id', [EventsController, 'show'])
        router.patch('/events/:id', [EventsController, 'update'])
        router.delete('/events/:id', [EventsController, 'destroy'])

        router.get('/routines', [RoutinesController, 'index'])
        router.post('/routines', [RoutinesController, 'store'])
        router.patch('/routines/:id', [RoutinesController, 'update'])
        router.delete('/routines/:id', [RoutinesController, 'destroy'])

        router.get('/calendar-sources', [CalendarSourcesController, 'index'])
        router.post('/calendar-sources', [CalendarSourcesController, 'store'])
        router.post('/calendar-sources/import', [CalendarSourcesController, 'importFile'])
        router.post('/calendar-sources/:id/sync', [CalendarSourcesController, 'sync'])
        router.patch('/calendar-sources/:id', [CalendarSourcesController, 'update'])
        router.delete('/calendar-sources/:id', [CalendarSourcesController, 'destroy'])

        router.post('/sync/push', [SyncController, 'push'])
        router.get('/sync/pull', [SyncController, 'pull'])
      })
      .use(middleware.auth())
  })
  .prefix('/api/v1')
