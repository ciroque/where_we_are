# WhereWeAre

A small Phoenix LiveView app that mirrors family calendars from CalDAV
(typically iCloud) and shows a shared month view: where everyone is, and when.

## Features

- Polls CalDAV on a configurable interval and keeps events in memory
- LiveView month grid with multi-day events, filters, and event detail modal
- Auto-refresh when sync completes; highlights “today” across midnight
- Optional calendar allow-list and CalDAV color support

## Quick start

```bash
mix setup
mix phx.server
```

Visit [http://localhost:4000](http://localhost:4000).

## Configuration

Runtime options are loaded from the environment (`config/runtime.exs` via
`WhereWeAre.CalendarSync.Config`):

| Variable | Purpose | Default |
|----------|---------|---------|
| `CALDAV_USERNAME` | CalDAV username | — |
| `CALDAV_PASSWORD` | CalDAV app-specific password | — |
| `CALDAV_URL` | CalDAV base URL | iCloud (`https://caldav.icloud.com`) |
| `CALDAV_CALENDARS` | Comma-separated calendar display names to include | all calendars |
| `CALDAV_EVENT_WINDOW_MONTHS` | Months before/after today to fetch | `6` |
| `CALDAV_EXPAND_RECURRENCES` | Expand recurring events at fetch | `true` |
| `CALDAV_POLL_MINUTES` | Sync poll interval | `10` |
| `SECRET_KEY_BASE` | Phoenix secret (required in prod) | — |
| `PHX_HOST` / `PORT` | Production endpoint host/port | — |
| `PHX_SERVER` | Set `true` for releases that should listen | — |

## Architecture

```
Calendar.Client behaviour
  ├── Calendar.NoopClient          # default / empty
  └── CalendarSync.CaldavClient    # CalDAVEx adapter → Calendar.Event structs

CalendarSync (GenServer)
  └── CalendarSync.Store           # pure state, month queries, redacted status
        └── Calendar.Window        # exclusive dtend, overlap, grid days

WhereWeAreWeb.CalendarLive
  ├── Calendar.Assigns             # pure assign builders
  ├── Calendar.ViewModel           # grid / agenda view models
  └── CalendarComponents           # function components for the UI
```

PubSub topic `calendar_sync:<server>` broadcasts `:events_updated` after each
sync attempt (success or failure). LiveView refreshes events and optionally
shows a sync error banner.

Legacy URL `/static` redirects to `/`.

## Development

```bash
mix test
mix credo --strict
mix dialyzer
```

## Deployment

- Multi-stage `Dockerfile` builds a release
- Helm chart under `chart/where-we-are/`
- Single-node in-memory sync: if you run multiple replicas, use sticky sessions
  or accept that each pod has its own cache

## Refactoring notes

See [REFACTORING_PLAN.md](./REFACTORING_PLAN.md) for the domain-first refactor
that produced the current layout, including the stacked branch plan.
