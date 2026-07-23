Build the booking engine.

The booking engine must exist entirely inside PostgreSQL.

The frontend may never insert bookings directly.

Implement:

RPC create_booking()

Transactional booking

FOR UPDATE locking

Advisory locks

Availability engine

Hold expiry

Booking state machine

Booking events

Buffer times

Working hours

Blocked dates

Holiday support

Cancellation rules

Lead times

Maximum future booking window

Validation

Return structured responses.

Write complete SQL migrations.

Write tests.

Do not build UI.
