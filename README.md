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

### Container image

Multi-stage `Dockerfile` builds a production release. CI pushes signed images to
GHCR (`ghcr.io/<owner>/where_we_are`) on merge to `main` (see
`.github/workflows/build-signed-image.yml`).

```bash
# Local build (optional)
docker build -t where-we-are:local .
```

### Helm

Chart path: `chart/where-we-are/`.

Calendar state is **in-memory per pod**. Keep `replicaCount: 1` unless you add
session affinity and accept divergent caches.

```bash
# 1) Generate a stable Phoenix secret (do not regenerate on every upgrade)
mix phx.gen.secret

# 2) Copy and edit overrides
cp chart/where-we-are/values.example.yaml my-values.yaml
# set secretKeyBase, caldav.*, env.PHX_HOST, image.tag, ingress, imagePullSecrets

# 3) Private GHCR image pull secret (if the package is private)
kubectl create namespace where-we-are
kubectl -n where-we-are create secret docker-registry ghcr-pull \
  --docker-server=ghcr.io \
  --docker-username=YOUR_GITHUB_USER \
  --docker-password=YOUR_GITHUB_PAT

# 4) Install / upgrade
helm upgrade --install where-we-are chart/where-we-are \
  --namespace where-we-are \
  --create-namespace \
  -f my-values.yaml

# 5) Verify
kubectl -n where-we-are get pods,svc,ingress
kubectl -n where-we-are logs -l app.kubernetes.io/name=where-we-are -f
```

Required values:

| Value | Notes |
|-------|--------|
| `secretKeyBase` | From `mix phx.gen.secret`; keep stable across upgrades |
| `caldav.username` / `caldav.password` | iCloud needs an [app-specific password](https://support.apple.com/en-us/HT204397) |
| `env.PHX_HOST` | Public hostname browsers use (must match ingress host) |
| `image.repository` / `image.tag` | Image from GHCR or your registry |

Optional CalDAV knobs: `caldav.calendars`, `caldav.url`, `caldav.eventWindowMonths`,
`caldav.expandRecurrences`, `caldav.pollMinutes`.

```bash
helm lint chart/where-we-are
helm template where-we-are chart/where-we-are -f my-values.yaml | less
```

## Refactoring notes

See [REFACTORING_PLAN.md](./REFACTORING_PLAN.md) for the domain-first refactor
that produced the current layout, including the stacked branch plan.
