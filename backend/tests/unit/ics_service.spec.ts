import { test } from '@japa/runner'
import IcsService from '#services/ics_service'

const calendar = `BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Agenda Test//FR
BEGIN:VEVENT
UID:course-1@example.test
DTSTART:20261005T070000Z
DTEND:20261005T083000Z
SUMMARY:Cours IA
DESCRIPTION:Révision des modèles
LOCATION:Salle 12
RRULE:FREQ=WEEKLY;BYDAY=MO
END:VEVENT
END:VCALENDAR`

test.group('IcsService', () => {
  test('parses VEVENT fields and preserves UID and RRULE', ({ assert }) => {
    const events = new IcsService().parse(calendar)

    assert.lengthOf(events, 1)
    assert.equal(events[0].uid, 'course-1@example.test')
    assert.equal(events[0].title, 'Cours IA')
    assert.equal(events[0].startAt.toISO(), '2026-10-05T07:00:00.000Z')
    assert.equal(events[0].endAt.toISO(), '2026-10-05T08:30:00.000Z')
    assert.equal(events[0].recurrenceRule, 'FREQ=WEEKLY;BYDAY=MO')
  })

  test('rejects invalid calendar content', ({ assert }) => {
    assert.throws(() => new IcsService().parse('not a calendar'), 'Invalid iCalendar content')
  })
})
