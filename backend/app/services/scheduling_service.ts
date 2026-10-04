import { DateTime, Interval } from 'luxon'

export interface BusySlot {
  start: DateTime
  end: DateTime
}

export interface WorkingHours {
  startHour: number
  endHour: number
  workingWeekdays?: number[]
}

export interface FindAvailableSlotsInput {
  duration: number
  from: DateTime
  to: DateTime
  workingHours: WorkingHours
  busySlots: BusySlot[]
}

export default class SchedulingService {
  findAvailableSlots(input: FindAvailableSlotsInput): BusySlot[] {
    const weekdays = input.workingHours.workingWeekdays ?? [1, 2, 3, 4, 5]
    const busy = input.busySlots
      .map((slot) => Interval.fromDateTimes(slot.start, slot.end))
      .filter((slot) => slot.isValid)
      .sort((left, right) => left.start!.toMillis() - right.start!.toMillis())
    const available: BusySlot[] = []

    for (let day = input.from.startOf('day'); day < input.to; day = day.plus({ days: 1 })) {
      if (!weekdays.includes(day.weekday)) continue
      const workStart = day.set({ hour: input.workingHours.startHour })
      const workEnd = day.set({ hour: input.workingHours.endHour })
      let cursor = DateTime.max(workStart, input.from)
      const boundary = DateTime.min(workEnd, input.to)

      for (const occupied of busy) {
        if (occupied.end! <= cursor || occupied.start! >= boundary) continue
        if (occupied.start!.diff(cursor, 'minutes').minutes >= input.duration) {
          available.push({ start: cursor, end: cursor.plus({ minutes: input.duration }) })
        }
        if (occupied.end! > cursor) cursor = occupied.end!
      }

      if (boundary.diff(cursor, 'minutes').minutes >= input.duration) {
        available.push({ start: cursor, end: cursor.plus({ minutes: input.duration }) })
      }
    }

    return available
  }
}
