import { BaseSchema } from '@adonisjs/lucid/schema'

export default class extends BaseSchema {
  protected tableName = 'sync_operations'

  async up() {
    this.schema.createTable(this.tableName, (table) => {
      table.uuid('id').primary()
      table.uuid('user_id').notNullable().references('id').inTable('users').onDelete('CASCADE')
      table.string('entity_type', 64).notNullable()
      table.uuid('entity_id').notNullable()
      table.timestamp('processed_at', { useTz: true }).notNullable()
      table.index(['user_id', 'processed_at'])
    })
  }

  async down() {
    this.schema.dropTable(this.tableName)
  }
}
