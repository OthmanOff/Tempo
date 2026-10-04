import { BaseSchema } from '@adonisjs/lucid/schema'

const taskStatuses = ['inbox', 'todo', 'scheduled', 'in_progress', 'completed', 'cancelled']
const taskPriorities = ['none', 'low', 'medium', 'high', 'urgent']
const eventSources = ['local', 'ics', 'external']
const calendarSourceTypes = ['local', 'ics_url', 'ics_file']

export default class extends BaseSchema {
  async up() {
    this.schema.createTable('projects', (table) => {
      table.uuid('id').primary().notNullable()
      table.uuid('user_id').notNullable().references('id').inTable('users').onDelete('CASCADE')
      table.string('name', 160).notNullable()
      table.text('description').nullable()
      table.string('icon', 80).nullable()
      table.string('color', 32).nullable()
      table.timestamp('archived_at', { useTz: true }).nullable()
      this.addSyncColumns(table)

      table.index(['user_id', 'archived_at'])
    })

    this.schema.createTable('calendar_sources', (table) => {
      table.uuid('id').primary().notNullable()
      table.uuid('user_id').notNullable().references('id').inTable('users').onDelete('CASCADE')
      table.string('name', 160).notNullable()
      table.enum('type', calendarSourceTypes).notNullable()
      table.text('url').nullable()
      table.boolean('enabled').notNullable().defaultTo(true)
      table.timestamp('last_synced_at', { useTz: true }).nullable()
      this.addSyncColumns(table)

      table.index(['user_id', 'enabled'])
    })

    this.schema.createTable('tasks', (table) => {
      table.uuid('id').primary().notNullable()
      table.uuid('user_id').notNullable().references('id').inTable('users').onDelete('CASCADE')
      table.uuid('project_id').nullable().references('id').inTable('projects').onDelete('SET NULL')
      table.uuid('parent_task_id').nullable().references('id').inTable('tasks').onDelete('SET NULL')
      table.string('title', 500).notNullable()
      table.text('description').nullable()
      table.enum('status', taskStatuses).notNullable().defaultTo('inbox')
      table.enum('priority', taskPriorities).notNullable().defaultTo('none')
      table.integer('estimated_duration_minutes').nullable()
      table.timestamp('due_at', { useTz: true }).nullable()
      table.timestamp('scheduled_start_at', { useTz: true }).nullable()
      table.timestamp('scheduled_end_at', { useTz: true }).nullable()
      table.timestamp('completed_at', { useTz: true }).nullable()
      table.integer('sort_order').notNullable().defaultTo(0)
      this.addSyncColumns(table)

      table.index(['user_id', 'status'])
      table.index(['user_id', 'due_at'])
      table.index(['user_id', 'scheduled_start_at'])
      table.index(['project_id', 'status'])
    })

    this.schema.createTable('events', (table) => {
      table.uuid('id').primary().notNullable()
      table.uuid('user_id').notNullable().references('id').inTable('users').onDelete('CASCADE')
      table.uuid('project_id').nullable().references('id').inTable('projects').onDelete('SET NULL')
      table
        .uuid('calendar_source_id')
        .nullable()
        .references('id')
        .inTable('calendar_sources')
        .onDelete('SET NULL')
      table.string('title', 500).notNullable()
      table.text('description').nullable()
      table.string('location', 500).nullable()
      table.timestamp('start_at', { useTz: true }).notNullable()
      table.timestamp('end_at', { useTz: true }).notNullable()
      table.boolean('all_day').notNullable().defaultTo(false)
      table.text('recurrence_rule').nullable()
      table.enum('source', eventSources).notNullable().defaultTo('local')
      table.string('external_id', 512).nullable()
      this.addSyncColumns(table)

      table.index(['user_id', 'start_at', 'end_at'])
      table.unique(['calendar_source_id', 'external_id'])
    })

    this.schema.createTable('routines', (table) => {
      table.uuid('id').primary().notNullable()
      table.uuid('user_id').notNullable().references('id').inTable('users').onDelete('CASCADE')
      table.uuid('project_id').nullable().references('id').inTable('projects').onDelete('SET NULL')
      table.string('name', 160).notNullable()
      table.text('recurrence_rule').notNullable()
      table.integer('preferred_duration_minutes').notNullable()
      table.time('preferred_start_time').nullable()
      table.boolean('enabled').notNullable().defaultTo(true)
      this.addSyncColumns(table)

      table.index(['user_id', 'enabled'])
    })
  }

  async down() {
    this.schema.dropTable('routines')
    this.schema.dropTable('events')
    this.schema.dropTable('tasks')
    this.schema.dropTable('calendar_sources')
    this.schema.dropTable('projects')
  }

  private addSyncColumns(table: Parameters<Parameters<typeof this.schema.createTable>[1]>[0]) {
    table.timestamp('created_at', { useTz: true }).notNullable()
    table.timestamp('updated_at', { useTz: true }).notNullable()
    table.timestamp('deleted_at', { useTz: true }).nullable()
    table.index(['updated_at'])
    table.index(['deleted_at'])
  }
}
