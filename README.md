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
| `PHX_HOST` / `PORT` | Production endpoint host/port | `example.com` / `4000` |
| `PHX_SERVER` | Set `true` for releases that should listen | — |

## Architecture

~~~
WhereWeAre.Calendar.Client behaviour
  ├── WhereWeAre.Calendar.NoopClient        # default / empty
  └── WhereWeAre.CalendarSync.CaldavClient  # CalDAVEx adapter → WhereWeAre.Calendar.Event structs

WhereWeAre.CalendarSync (GenServer)
  └── WhereWeAre.CalendarSync.Store         # pure state, month queries, redacted status
        └── WhereWeAre.Calendar.Window      # exclusive dtend, overlap, grid days

WhereWeAreWeb.CalendarLive
  ├── WhereWeAreWeb.Calendar.Assigns        # pure assign builders
  ├── WhereWeAreWeb.Calendar.ViewModel      # grid / agenda view models
  └── WhereWeAreWeb.CalendarComponents      # function components for the UI
~~~

PubSub topic `calendar_sync:<server>` broadcasts `:events_updated` after each
sync attempt (success or failure). LiveView refreshes events and optionally
shows a sync error banner.

## Development

```bash
mix test
mix credo --strict
mix dialyzer
```

## Deployment

Multi-stage `Dockerfile` builds a production release. CI pushes signed images to
`ghcr.io/ciroque/where_we_are` on merge to `main`.

The Helm chart (`chart/where-we-are/`) uses digest-pinned images, Traefik
ingress, cert-manager, and GHCR pull secret `ghcr-package-read`. See
[chart/where-we-are/README.md](./chart/where-we-are/README.md).

```bash
export DIGEST=sha256:...   # from GHCR / CI
export HOST=where-we-are.example.com
export CALDAV_APP_PASSWORD=...   # iCloud app-specific password
# Generate once: mix phx.gen.secret
export WHERE_WE_ARE_SECRET_KEY_BASE="..."  # keep stable across upgrades

helm upgrade --install where-we-are ./chart/where-we-are \
  --set app.secretKeyBase="$WHERE_WE_ARE_SECRET_KEY_BASE" \
  --set app.phxHost="$HOST" \
  --set app.caldav.username="you@icloud.com" \
  --set app.caldav.password="$CALDAV_APP_PASSWORD" \
  --set image.digest="$DIGEST" \
  --set ingress.enabled=true \
  --set ingress.hosts[0].host="$HOST" \
  --set ingress.tls[0].hosts[0]="$HOST" \
  --set ingress.tls[0].secretName=where-we-are-tls-secret \
  --set certificate.enabled=true \
  --set certificate.dnsNames[0]="$HOST" \
  -n where-we-are --create-namespace
```

Keep `replicaCount: 1` — calendar state is in-memory per pod.

## Refactoring notes

See [REFACTORING_PLAN.md](./REFACTORING_PLAN.md) for the domain-first refactor
that produced the current layout, including the stacked branch plan.
