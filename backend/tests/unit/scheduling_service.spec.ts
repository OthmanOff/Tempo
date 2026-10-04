import { DateTime } from 'luxon'
import { test } from '@japa/runner'
import SchedulingService from '#services/scheduling_service'

test.group('SchedulingService', () => {
  test('finds free slots around existing activities', ({ assert }) => {
    const service = new SchedulingService()
    const day = DateTime.fromISO('2026-10-05T00:00:00', { zone: 'Europe/Paris' })

    const slots = service.findAvailableSlots({
      duration: 60,
      from: day,
      to: day.plus({ days: 1 }),
      workingHours: { startHour: 9, endHour: 17 },
      busySlots: [
        { start: day.set({ hour: 10 }), end: day.set({ hour: 11 }) },
        { start: day.set({ hour: 13 }), end: day.set({ hour: 15 }) },
      ],
    })

    assert.deepEqual(
      slots.map((slot) => [slot.start.toFormat('HH:mm'), slot.end.toFormat('HH:mm')]),
      [
        ['09:00', '10:00'],
        ['11:00', '12:00'],
        ['15:00', '16:00'],
      ]
    )
  })

  test('skips non-working days', ({ assert }) => {
    const service = new SchedulingService()
    const saturday = DateTime.fromISO('2026-10-03T00:00:00', { zone: 'Europe/Paris' })

    const slots = service.findAvailableSlots({
      duration: 60,
      from: saturday,
      to: saturday.plus({ days: 2 }),
      workingHours: { startHour: 9, endHour: 17 },
      busySlots: [],
    })

    assert.isEmpty(slots)
  })
})
