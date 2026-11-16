# Hotel Reservation System (SQL)

A hotel reservation database built in **MariaDB 10.11** (MySQL-compatible), covering schema design, CRUD, double-booking prevention, season-aware billing, indexing, views and window functions.

## Features

- **Schema**: 6 tables + a calendar helper table, with primary keys, foreign keys, `CHECK` constraints and an `ENUM` status column
- **CRUD**: create / read / update / delete for guests and reservations
- **No double bookings**: `INSERT ... WHERE NOT EXISTS` overlap check on bookings, stay extensions and room moves
- **Season-aware billing**: each night is billed at the rate valid on that night
- **Indexing**: composite index on `(room_id, check_in_date, check_out_date)`, email index, `UNIQUE` vs plain index, compared with `EXPLAIN`
- **Views**: room availability calendar, guest billing summary, restricted front-desk view with `WITH CHECK OPTION`
- **Window functions**: `RANK()`, running totals, `LAG()`, `NTILE(4)`

## Project structure

```
sql/
  01_schema.sql                        tables, constraints, calendar_dates
  02_sample_data.sql                   room types, rooms, rates, guests, random reservations
  03_crud.sql                          create / read / update / delete
  04_availability_billing_assignment.sql   free rooms, bill calculation, room assignment
  05_indexing.sql                      indexes + EXPLAIN comparisons
  06_views.sql                         availability, billing, front-desk views
  07_window_functions.sql              RANK, running total, LAG, NTILE
```

## How to run

```bash
mysql -u root -p < sql/01_schema.sql
mysql -u root -p < sql/02_sample_data.sql
mysql -u root -p < sql/03_crud.sql
mysql -u root -p < sql/04_availability_billing_assignment.sql
mysql -u root -p < sql/05_indexing.sql
mysql -u root -p < sql/06_views.sql
mysql -u root -p < sql/07_window_functions.sql
```

Run them in order: each file depends on the ones before it.

## Assumptions

- A stay is a half-open interval: the guest occupies the room from check-in up to, but not including, check-out, so one guest can leave on the 14th and another arrive on the 14th.
- Cancelled reservations do not block a room and do not count towards revenue or billing.
- Nightly rate depends on room type and season; a stay crossing two seasons is billed night by night.
- The bill is calculated by a view, not stored, so it can never go out of date.
- Amounts are in Indian rupees. "Today" in the sample data is **9 November 2026**.
- Sample data is synthetic and randomly generated, so exact counts and revenue figures change slightly each run.

## Security note

`06_views.sql` creates a `frontdesk` user with a placeholder password. Change it before using this anywhere real.
