# WhereWeAre — Ideal Refactoring Plan

**Author stance:** Principal Engineer review (read-only; no code changes in this document’s delivery).  
**Date:** 2026-04-10  
**Scope:** Application code under `lib/`, `test/`, `assets/js`, and related config. Phoenix/Helm boilerplate is in-scope only where it blocks the refactor.  
**Guiding values (in priority order):**

1. Readability  
2. Simplicity  
3. Maintainability  
4. Testability  
5. Modularity  
6. Consistency  
7. Error handling  
8. Reusability / DRY  
9. Scalability  
10. Performance  

---

## 1. What this system is

**WhereWeAre** is a small Phoenix 1.7 app that:

1. Polls a CalDAV server (typically iCloud) via a supervised GenServer (`WhereWeAre.CalendarSync`).
2. Holds events in memory and broadcasts `:events_updated` over PubSub.
3. Renders a month calendar:
   - **Primary UI:** LiveView at `/` (`CalendarLive`) — filters, modal, live refresh, day rollover.
   - **Secondary UI:** controller + HEEx at `/static` (`PageController` / `home.html.heex`) — full page navigations, no filters/modal.

There is no database. Configuration is environment-driven (`CalendarSync.Config` → `runtime.exs`). Tests are solid for the size of the app and already exercise pure helpers, the GenServer, and LiveView flows.

**Judgement:** This is a healthy product surface with clear value. The main risk is not “big ball of mud” — it is **accidental complexity from dual UIs, untyped event maps, and domain rules living in three places**. Refactor for clarity, not for framework fashion.

---

## 2. Current architecture (as-is)

```
                    env vars
                       │
                       ▼
            CalendarSync.Config.from_env/0
                       │
                       ▼
┌──────────────────────────────────────────────────────┐
│ Application                                          │
│  Telemetry · PubSub · CalendarSync · Endpoint        │
└──────────────────────────┬───────────────────────────┘
                           │
              client.fetch_events(config)
                           │
                           ▼
                   CaldavClient ──► CalDAVEx
                           │
                    events (maps)
                           │
          ┌────────────────┴────────────────┐
          ▼                                 ▼
   CalendarLive (/)                  PageController (/static)
   + calendar_live.html.heex         + home.html.heex
          │                                 │
          └──────── CalendarHelpers ────────┘
                    PageHTML.calendar_color/*
```

### Module inventory (domain-relevant)

| Area | Module | Role today |
|------|--------|------------|
| OTP | `WhereWeAre.CalendarSync` | GenServer: poll, store, query, PubSub |
| Client | `CalendarSync.CaldavClient` | Auth, discover, list calendars, fetch events |
| Client | `CalendarSync.NoopClient` (nested) | Empty client default / tests |
| Config | `CalendarSync.Config` | Env → GenServer opts |
| Web | `CalendarLive` | Session, mount, filters, modal, day timer |
| Web | `PageController` / `PageHTML` | Static calendar + **color palette** |
| Web | `CalendarHelpers` | Timezone + multi-day expansion for **rendering** |
| Sync | (private in GenServer) | Month overlap + exclusive `dtend` for **query** |

---

## 3. Assessment against clean-code values

### 3.1 Strengths (keep these)

- **Injectable client** on `CalendarSync` is the right seam for testing and defaults.
- **PubSub refresh** for LiveView is simple and appropriate for a single-node in-memory store.
- **Tests** cover exclusive `dtend`, multi-day overlap, LiveView navigation, and color normalization — good safety net for refactoring.
- **Config parsing** (`Config.from_env/0`) is focused and well-tested.
- **Helm + multi-stage Docker** are reasonable for the deployment story.

### 3.2 Issues (ordered by priority values)

#### P0 — Readability / Simplicity

| ID | Finding | Why it hurts |
|----|---------|--------------|
| R1 | **Dual calendar UIs** (`/` vs `/static`) with ~80% duplicated HEEx and parallel month-resolution logic | Every UI change is twice the work and twice the risk of drift (already true: LiveView has filters, colors from CalDAV, modal; static does not). |
| R2 | **Events are free-form maps** (`:uid`/`:summary` in prod UI; `:id`/`:title` in some tests) | Readers cannot know the contract; Dialyzer and editors cannot help. |
| R3 | **Domain date rules live in two modules** | Exclusive `dtend` and range logic in both `CalendarSync` and `CalendarHelpers` — same RFC-ish rules, different code paths. |
| R4 | **Heavy logic inside HEEx** | Grid construction, `events_by_date`, past/upcoming split — hard to read and untestable without rendering. |
| R5 | **`PageHTML` owns calendar colors** while LiveView calls into it | Naming lies: colors are not “page HTML”; LiveView depending on a controller HTML module is surprising. |

#### P1 — Maintainability / Testability / Modularity

| ID | Finding | Why it hurts |
|----|---------|--------------|
| M1 | **`CalendarLive` is a god module** (~320 lines): session cookies, timezone, month params, calendar discovery fallbacks, selection cookies, filtering, modal, midnight timer | Hard to change one concern without rereading all of them. |
| M2 | **No `@behaviour` for the calendar client** | The contract is implicit; easy to break fakes. |
| M3 | **`credentials` map is overloaded** | Holds username/password **and** `url` **and** `calendars` filter. “Credentials” is the wrong name for half of its contents. |
| M4 | **`Mix.env() == :test` compile branch** for `{:set_events, _}` | Couples production module shape to test; different BEAM code in test vs prod. Prefer a test client or a documented test-only API behind a clear module. |
| M5 | **Month filtering requires GenServer calls** | Pure “given events + month → events” logic is trapped behind `GenServer.call`, making unit tests heavier than needed. |

#### P2 — Consistency / Error handling

| ID | Finding | Why it hurts |
|----|---------|--------------|
| C1 | **Credential validation duplicated** three times in `CaldavClient` (`authenticate`, `list_calendars`, `fetch_events`, plus `validate_config`) | Drift risk; noisy file. |
| C2 | **`public_state/1` returns raw credentials** (including password) to any caller of `state/1` | LiveView only needs `credentials.calendars`. Accidental logging or future API exposure becomes a secret leak. |
| C3 | **Sync errors are stored but never surfaced in the UI** | `last_error` exists; operators/users get no signal when CalDAV is down (silent stale calendar). |
| C4 | **Timezone cookie set via inline `<script>`**; calendar selection via `push_event` | Two persistence mechanisms for similar “browser preference” concerns. |

#### P3 — DRY / Scalability / Performance (lower urgency)

| ID | Finding | Notes |
|----|---------|-------|
| D1 | Month param / timezone resolution duplicated in `PageController` and `CalendarLive` | Extract once. |
| D2 | Full event list held in GenServer; month filter scans all events | Fine at family-calendar scale; only optimize after a typed store exists. |
| D3 | `list_calendars` on every LiveView mount / events refresh | Extra CalDAV work when discovery could be cached alongside events in sync state. |
| D4 | Stock Phoenix `core_components.ex` (~677 lines) largely unused | Not wrong; prune later if noise bothers you — not a product refactor. |

### 3.3 Explicit non-goals

Do **not** pursue in this refactor unless requirements change:

- Introducing Ecto / Postgres for calendar data (YAGNI for a polled mirror).
- Multi-node shared cache (single replica is fine; document stickiness if replicas > 1).
- Replacing LiveView with SPA frameworks.
- Full iCalendar RRULE engine of your own (keep `expand_recurrences` at the CalDAV client).
- GraphQL / JSON API for clients (no consumers).

---

## 4. Target architecture (to-be)

### 4.1 Layering

```
WhereWeAre.Calendar                  # pure domain
  Event                              # struct + constructors/normalizers
  Window                             # exclusive dtend, overlap, month filter, sort
  Color                              # palette + hex contrast (no Phoenix)

WhereWeAre.Calendar.Client           # behaviour
  Caldav                             # CalDAVEx adapter (today: CaldavClient)
  Noop

WhereWeAre.Calendar.Sync             # OTP (today: CalendarSync)
  Config                             # env → typed options
  Server                             # GenServer: fetch, store, schedule, pubsub
  (optional) Store                   # pure: apply fetch result, filter, public view

WhereWeAreWeb.Calendar               # web
  Live                               # thin LiveView
  Components.*                       # function components (grid, list, modal, nav, filters)
  Session / Params                   # timezone, month, selected calendars
  (optional) StaticController        # thin wrapper reusing components — or delete
```

Naming note: prefer **either** keep `WhereWeAre.CalendarSync` names and extract under that namespace, **or** rename once to `WhereWeAre.Calendar.*`. Do not half-rename. Section 6 recommends **extract-first, rename-last** to keep diffs reviewable.

### 4.2 Domain contracts

```elixir
defmodule WhereWeAre.Calendar.Event do
  @enforce_keys [:uid, :dtstart]
  defstruct [
    :uid,
    :summary,
    :dtstart,          # Date | DateTime
    :dtend,            # Date | DateTime | nil  (iCal exclusive end when present)
    :location,
    :description,
    :status,
    :calendar_name,
    :calendar_color
  ]
end

@callback fetch_events(config :: map()) ::
            {:ok, [WhereWeAre.Calendar.Event.t()]} | {:error, term()}

@callback list_calendars(config :: map()) ::
            {:ok, [calendar_info()]} | {:error, term()}
```

Normalize CalDAV maps → `Event` **at the adapter boundary**. UI and GenServer never invent field names.

### 4.3 Single source of date truth

One pure module (name proposal: `WhereWeAre.Calendar.Window`) owns:

- Exclusive end date for `Date` / `DateTime` (RFC 5545-style “end is exclusive”)
- “Event overlaps date range?” (month query)
- “Days this event occupies in a grid?” (rendering)
- Sort key for chronological lists
- Past vs upcoming split relative to a local “today”

Both GenServer month queries and HEEx grid building call this module. **Delete the duplicate private functions** in `CalendarSync` and shrink `CalendarHelpers` to thin timezone wrappers — or fold timezone helpers into `Window` / `Calendar.Time` and delete `CalendarHelpers`.

### 4.4 UI strategy (decision required — recommendation included)

| Option | Description | Recommendation |
|--------|-------------|----------------|
| **A. LiveView only** | Delete `/static`, `PageController` calendar action, and `home.html.heex` calendar markup | **Recommended** if no SEO/no-JS requirement is documented |
| **B. Shared components** | Keep `/static` as progressive enhancement; both routes render the same function components | Choose if you need crawlers or no-JS deliberately |
| **C. Status quo** | Leave dual trees | Reject — violates readability and DRY |

**Default plan assumes Option A.** If you need B, Phase 5 keeps a thin controller that assigns the same data shape components expect.

### 4.5 LiveView shape

After refactor, `CalendarLive` should mostly:

1. Resolve session/params → assigns  
2. Subscribe / schedule timers  
3. Handle user events (nav, toggle, modal)  
4. React to `:events_updated` / `:day_changed`  
5. Delegate filtering and view-model building to pure functions  

Target: **~100–150 lines** of LiveView + small pure module(s) + components.

### 4.6 Sync process shape

GenServer responsibilities only:

- Hold last successful event list + last sync + last error + calendar catalog (if cached)
- Schedule polls
- Call client
- Broadcast

**Pure** functions outside the process:

- Filter by month  
- Build public status (redacted)  
- Merge calendar names/colors from server + events  

Expose:

```elixir
CalendarSync.events_for_month(server, month)  # may stay as call for consistency
CalendarSync.status(server)                   # last_sync, last_error, configured_calendars — no password
CalendarSync.calendars(server)                # cached catalog if available
```

Avoid returning password-bearing maps from any public API.

---

## 5. Ideal end-state checklist

When finished, a new contributor should be able to answer in minutes:

1. What is an Event? → one struct, one file.  
2. How does exclusive end work? → one pure module + tests.  
3. How does CalDAV enter the system? → one behaviour, one adapter.  
4. How does the UI render a month? → one set of function components.  
5. What can go wrong on sync? → `status.last_error` + UI affordance.  

Metrics of success (not vanity):

- No duplicated exclusive-`dtend` logic  
- No LiveView → `PageHTML` dependency  
- Calendar client fakes implement a real behaviour  
- `mix test` still green; no intentional behavior change except explicit UX improvements (error banner, optional `/static` removal)  
- GenServer module free of `Mix.env()` conditionals  

---

## 6. Implementation plan (phased, commit-hygienic)

### Commit hygiene rules (apply to every phase)

1. **One intent per commit.** Message format:  
   `refactor(calendar): extract exclusive dtend into Calendar.Window`  
   Prefer `refactor`, `test`, `fix`, `feat` scopes.
2. **Tests land with or before behavior changes.** Prefer “add characterization tests → refactor → tests still pass.”
3. **No mixed drive-bys.** Do not reformat `core_components.ex` in a domain commit.
4. **Keep the tree green after every commit** (`mix test` at minimum; `mix credo` / `mix dialyzer` at phase ends).
5. **Stacked commits / stacked PRs are preferred** when a phase exceeds ~300 lines of meaningful diff. Suggested stack:

   ```
   main
    └── refactor/calendar-window          # Phase 1
         └── refactor/event-struct        # Phase 2
              └── refactor/client-behaviour # Phase 3
                   └── refactor/sync-pure   # Phase 4
                        └── refactor/web-components # Phase 5
                             └── refactor/liveview-slim # Phase 6
                                  └── refactor/sync-api-hygiene # Phase 7
                                       └── chore/docs-cleanup # Phase 8
   ```

6. **PR size:** aim for each PR reviewable in < 30 minutes. Prefer 4–8 commits per PR over one mega-commit.

---

### Phase 0 — Characterization safety net  
**Goal:** Lock current behavior before moving code.  
**Risk:** Low.  
**Estimated commits:** 1–2.

| Step | Work | Commit message (example) |
|------|------|--------------------------|
| 0.1 | Add pure-function tests that document exclusive `dtend` + month overlap **as exercised via the public GenServer API** if any gap exists (most already exist). | `test(calendar): characterize month overlap edge cases` |
| 0.2 | Add a short test that LiveView and (if kept) static paths agree on month label for a fixed date/events fixture — only if keeping dual UI. | `test(web): pin calendar month rendering contract` |

**Exit criteria:** Confidence that pure extractions will fail tests if logic drifts.

---

### Phase 1 — Single pure date window module  
**Goal:** One implementation of event day/range rules.  
**Values hit:** Readability, simplicity, DRY, testability.  
**Risk:** Medium (easy to get exclusive end wrong).  
**Estimated commits:** 2–3.

| Step | Work | Commit |
|------|------|--------|
| 1.1 | Create `WhereWeAre.Calendar.Window` (or `CalendarSync.EventWindow`) with pure functions: `end_date/2`, `overlaps_range?/3`, `days_in_range/4`, `sort_key/1`, `split_past_upcoming/2`. Move tests from `CalendarLiveTest` “event_dates” describe into a dedicated test file. | `refactor(calendar): introduce pure Event window helpers` |
| 1.2 | Change `CalendarHelpers` to delegate to Window (keep module as façade if web imports it). | `refactor(web): delegate CalendarHelpers to Window` |
| 1.3 | Change `CalendarSync` private `event_in_range?` / `event_end_date` / `event_sort_key` to call Window. Delete duplicates. | `refactor(sync): use Window for month filtering` |

**Do not** change public function names yet.  
**Exit criteria:** `mix test` green; `rg "event_end_date|event_in_range"` shows a single implementation.

---

### Phase 2 — Typed `Event` at the boundary  
**Goal:** Replace free-form maps in the core path with a struct.  
**Values hit:** Readability, consistency, maintainability.  
**Risk:** Medium (touches client, sync, live, tests).  
**Estimated commits:** 3–4.

| Step | Work | Commit |
|------|------|--------|
| 2.1 | Add `WhereWeAre.Calendar.Event` struct + `from_caldav/2` (or `new/1`) normalizer. Support both atom and string keys if CalDAVEx returns mixed shapes. | `feat(calendar): add Event struct and normalizer` |
| 2.2 | Have `CaldavClient` return `%Event{}` lists (still maps inside adapter until map→struct). | `refactor(caldav): emit Event structs` |
| 2.3 | Update GenServer, LiveView, helpers to pattern-match structs (`event.summary` vs `Map.get`). Keep `Map.get` only for optional fields if needed. | `refactor(calendar): consume Event structs end-to-end` |
| 2.4 | Fix tests that used `:id` / `:title` to use `:uid` / `:summary`. Add factory helper in `test/support/calendar_fixtures.ex`. | `test(calendar): unify event fixtures on Event struct` |

**Exit criteria:** No production code path documents `:title` for events; Dialyzer happy on Event fields if specs added.

---

### Phase 3 — Client behaviour + CalDAV cleanup  
**Goal:** Explicit port; less duplication; clearer fakes.  
**Values hit:** Modularity, testability, consistency.  
**Risk:** Low–medium.  
**Estimated commits:** 2–3.

| Step | Work | Commit |
|------|------|--------|
| 3.1 | Define `@behaviour WhereWeAre.Calendar.Client` (or `CalendarSync.Client`). Move `NoopClient` to its own file implementing the behaviour. | `refactor(calendar): define Client behaviour and extract NoopClient` |
| 3.2 | Collapse credential validation in `CaldavClient` into one `validate_config/1` used by all public entry points. | `refactor(caldav): single credential validation path` |
| 3.3 | Update all test doubles to `@behaviour` / `@impl true`. | `test(calendar): align fakes with Client behaviour` |

**Optional follow-up commit:** cache discovery inside a single fetch path so `list_calendars` + `list_events` do not re-discover thrice in one sync (performance — only if easy and tested).

---

### Phase 4 — Thin GenServer / pure store  
**Goal:** Separate process concerns from pure query logic.  
**Values hit:** Simplicity, testability, maintainability.  
**Risk:** Medium.  
**Estimated commits:** 3–4.

| Step | Work | Commit |
|------|------|--------|
| 4.1 | Extract pure module `CalendarSync.Store` (or `Calendar.Sync.State`) with: `new/1`, `put_events/2`, `put_error/2`, `events_for_month/2`, `public_status/1`. GenServer holds `%Store{}` and delegates. | `refactor(sync): extract pure Store from GenServer` |
| 4.2 | Unit-test Store without starting a process (port existing month tests where practical). Keep a few GenServer integration tests. | `test(sync): cover Store without OTP` |
| 4.3 | Replace `Mix.env() == :test` `set_events` with either: (a) `initial_events` + client that returns known data, or (b) a documented `CalendarSync.__test_put_events__/2` in `test/support` via `:sys.replace_state` / public test helper. Prefer (a). | `refactor(sync): remove Mix.env test branches` |
| 4.4 | Redact secrets in `public_status/1`. Add `configured_calendars/1` so LiveView does not dig into credentials. | `fix(sync): stop exposing CalDAV password via state/1` |

**Exit criteria:** LiveView never reads `state.credentials.password`; no `Mix.env` in `lib/`.

---

### Phase 5 — Shared web components (and dual-UI decision)  
**Goal:** One visual calendar implementation.  
**Values hit:** Readability, DRY, consistency.  
**Risk:** Medium–high (UI parity).  
**Estimated commits:** 3–5.

| Step | Work | Commit |
|------|------|--------|
| 5.1 | Move color palette + hex contrast from `PageHTML` to `WhereWeAre.Calendar.Color` (pure) + thin `WhereWeAreWeb.CalendarComponents` wrappers if needed for class maps. Point LiveView and static (if kept) at it. | `refactor(web): extract calendar colors from PageHTML` |
| 5.2 | Introduce function components:  
    - `month_header/1` (prev / title / next / today)  
    - `calendar_filters/1`  
    - `month_grid/1`  
    - `event_agenda/1` (past / upcoming)  
    - `event_modal/1`  
    Build **view model** in pure Elixir: `%{cells, events_by_date, month_label, ...}` so HEEx stays declarative. | `refactor(web): extract calendar function components` |
| 5.3 | Rewrite `calendar_live.html.heex` to compose components only. | `refactor(live): compose calendar from components` |
| 5.4a **(Option A)** Remove `/static` route, controller action, `home.html.heex` calendar, and obsolete controller tests (keep color tests moved). Update any docs/links. | `refactor(web): remove static calendar path in favor of LiveView` |
| 5.4b **(Option B)** Rewrite static template to use the same components; keep link-based nav via assigns. | `refactor(web): share components with static calendar` |

**Exit criteria:** Calendar markup exists in one place; color tests live next to `Color` module.

---

### Phase 6 — Slim `CalendarLive`  
**Goal:** LiveView as orchestration only.  
**Values hit:** Readability, modularity, maintainability.  
**Risk:** Medium.  
**Estimated commits:** 2–3.

| Step | Work | Commit |
|------|------|--------|
| 6.1 | Extract pure module `WhereWeAreWeb.Calendar.Selection` (or `CalendarLive.Assigns`): `resolve_timezone/1`, `resolve_month/2`, `resolve_selected/2`, `filter_events/2`, `merge_known_calendars/3`, `merge_colors/2`. Unit test without LiveView. | `refactor(live): extract pure assign builders` |
| 6.2 | Extract browser preference helpers (cookie session for tz + selected calendars) — ideally one JS path: LiveView hook sets both cookies, or server reads cookies only. Align with `app.js`. | `refactor(web): unify preference cookie handling` |
| 6.3 | Leave LiveView with mount / handle_* only; delete dead private functions. | `refactor(live): slim CalendarLive to orchestration` |

**Exit criteria:** `calendar_live.ex` reads top-to-bottom without nested domain algorithms.

---

### Phase 7 — Config shape, errors, operational clarity  
**Goal:** Honest naming; visible failure modes.  
**Values hit:** Error handling, maintainability, consistency.  
**Risk:** Low–medium (config key renames need care for env/Helm).  
**Estimated commits:** 2–4.

| Step | Work | Commit |
|------|------|--------|
| 7.1 | Split config options:  
    `auth: %{username, password}`  
    `server: %{url: ...}`  
    `filter: %{calendars: ...}`  
    `sync: %{poll_interval, event_window_months, expand_recurrences}`  
    Keep env var names stable; only internal keys change. Update Helm values docs if they document keys. | `refactor(config): separate auth, filter, and sync options` |
| 7.2 | Cache calendar catalog on successful sync; LiveView reads cache instead of calling CalDAV `list_calendars` on every refresh when possible. Fallback to event-derived names on error. | `feat(sync): cache calendar catalog with events` |
| 7.3 | Surface `last_error` in UI (dismissible banner) without leaking secrets. Add LiveView test. | `feat(live): show calendar sync errors` |
| 7.4 | Optional: make poll interval configurable via env (`CALDAV_POLL_MINUTES`) for ops parity with other knobs. | `feat(config): allow poll interval from env` |

---

### Phase 8 — Documentation & hygiene  
**Goal:** Match repo reality to mental model.  
**Risk:** Low.  
**Estimated commits:** 1–2.

| Step | Work | Commit |
|------|------|--------|
| 8.1 | Replace stock Phoenix README with project-specific: purpose, env vars, LiveView-only (or dual) routes, how sync works, how to run tests. | `docs: rewrite README for WhereWeAre` |
| 8.2 | Module moduledocs on public APIs only; delete stale comments. Optionally prune unused CoreComponents **only if** you want less scaffold noise (separate PR). | `docs(calendar): document public module contracts` |
| 8.3 | Mark this plan complete or supersede with “as-built” notes. | `docs: close refactoring plan gaps` |

---

## 7. Suggested commit stack (summary view)

Minimal stack if you want maximum reviewability:

1. `test: characterization for window edge cases`  
2. `refactor: introduce Calendar.Window; wire helpers + sync`  
3. `feat: Event struct + CalDAV normalizer`  
4. `refactor: Client behaviour + Noop extract + validation DRY`  
5. `refactor: pure Sync.Store; redact status; drop Mix.env branch`  
6. `refactor: Calendar.Color + function components`  
7. `refactor: LiveView uses components; remove /static` *(or share)*  
8. `refactor: pure Live assign builders; slim CalendarLive`  
9. `feat: cached calendars + error banner`  
10. `docs: README + module contracts`  

Each item can be one PR or one commit on a long-lived branch; prefer **one PR per phase (1–7)** with internal small commits.

---

## 8. Testing strategy during the refactor

| Layer | Prefer | Avoid |
|-------|--------|-------|
| Window / Event / Color / Store | Pure ExUnit, `async: true` | Starting GenServers |
| CaldavClient | Behaviour fakes (as today) | Real network |
| CalendarSync GenServer | Few integration tests: success, failure retention, broadcast | Re-testing pure month math only via OTP |
| LiveView | Navigation, filter, modal, error banner, pubsub refresh | Asserting Tailwind class soup unless meaningful |
| Fixtures | `test/support/calendar_fixtures.ex` | Ad-hoc maps per test with different keys |

**Regression command after each commit:**

```bash
mix test
```

**After each phase:**

```bash
mix test && mix credo --strict && mix dialyzer
```

---

## 9. Risk register

| Risk | Mitigation |
|------|------------|
| Exclusive `dtend` regressions (multi-day pills wrong) | Phase 0–1 tests; manual smoke on a known multi-day event |
| LiveView/static feature gap when deleting `/static` | Confirm no external links/bookmarks/monitors hit `/static` (Helm ingress, README) |
| Struct conversion breaks CalDAVEx field names | Normalizer with tests for atom/string keys; keep raw map only inside adapter |
| Password still leaks via logs | Redact in `public_status`; never `inspect` full state in Logger |
| Stacked PR bitrot | Rebase often; keep phases short; land Phase 1–2 quickly for payoff |
| Over-abstraction | Stop after Phase 6 if product is stable; Phase 7 is polish |

---

## 10. Out-of-order “quick wins” (if time is scarce)

If a full campaign is too much, do **only** these — highest value per line:

1. **Extract `Calendar.Window`** (Phase 1) — eliminates the most dangerous duplication.  
2. **Redact `state/1` credentials** (Phase 4.4) — security hygiene.  
3. **Move colors out of `PageHTML`** (Phase 5.1) — fixes the most confusing dependency.  
4. **Decide and delete `/static` or share components** (Phase 5.4) — stops dual maintenance.

Everything else can wait without blocking feature work.

---

## 11. Assumptions (no open blockers)

Proceeding with the plan assumes:

1. **LiveView is the product UI**; `/static` is legacy/no-JS fallback without a hard requirement (Option A).  
2. **Single-node deployment** remains the target (in-memory sync is fine).  
3. **CalDAVEx event maps** can be normalized without forking the library.  
4. **Env var names stay stable** during internal option reshaping.  
5. **No concurrent major feature branch** depends on map-shaped events with `:title`/`:id`.

If any assumption is false, adjust:

- Need no-JS → Option B in Phase 5.  
- Need multi-replica → add sticky sessions or external cache before scaling replicas; document in README.  
- Need public JSON → add a dedicated read API on top of Store, not by exposing GenServer internals.

---

## 12. Definition of done

The refactor is done when:

- [ ] Exclusive end / month overlap / grid days share one pure module with direct unit tests  
- [ ] Events are `%Event{}` from adapter through UI  
- [ ] Calendar client is a behaviour; Noop + fakes implement it  
- [ ] GenServer has no `Mix.env` branches; status API is redacted  
- [ ] Calendar UI markup is not duplicated across two templates  
- [ ] LiveView is orchestration-thin; pure assign builders are unit-tested  
- [ ] Sync failures are visible in the UI  
- [ ] README describes the real system  
- [ ] `mix test`, `mix credo --strict`, and `mix dialyzer` pass  

---

## 13. How I would staff this

| Phase | Effort (experienced Elixir/Phoenix) | Parallelizable? |
|-------|-------------------------------------|-----------------|
| 0–1 | 0.5–1 day | No (foundation) |
| 2–3 | 1–1.5 days | Slightly (behaviour after Event) |
| 4 | 0.5–1 day | No |
| 5–6 | 1–2 days | UI-focused |
| 7–8 | 0.5–1 day | Yes after 6 |

**Total:** roughly **4–7 focused days** for the full ideal path, or **1–2 days** for the quick-win subset.

---

## 14. Final recommendation

Treat this as a **domain-first refactor**, not a framework rewrite:

1. Pure calendar rules  
2. Typed events at the boundary  
3. Thin OTP + thin LiveView  
4. One UI composition tree  

That ordering maximizes **readability and simplicity** while using the existing test suite as a seatbelt. Resist the urge to introduce GenServers, caches, or databases that the product does not need yet — **scalability and performance are last for a reason**.

When you are ready to execute, start at Phase 0 on a branch named `refactor/calendar-window` and keep every commit green.

---

## 15. Execution status (2026-04-10)

Implemented and merged; originally developed as a local stacked branch tip at `chore/docs-cleanup`.

| Branch | Phase | Status |
|--------|-------|--------|
| `refactor/calendar-window` | Window extraction | Done |
| `refactor/event-struct` | Event struct | Done |
| `refactor/client-behaviour` | Client behaviour | Done |
| `refactor/sync-pure` | Pure Store + redaction | Done |
| `refactor/web-components` | Components; `/static` removed | Done |
| `refactor/liveview-slim` | Assigns + slim LiveView | Done |
| `refactor/sync-api-hygiene` | Config split, poll env, error UI | Done |
| `chore/docs-cleanup` | README + docs | Done |

Deviations from the original plan:

- `/static`, `PageController`, and `PageHTML` are **removed** (any mentions above refer to the pre-refactor plan); LiveView is the only UI.
- Sync error UI was wired with the component work and finished in the hygiene phase.
- Calendar catalog caching is best-effort after each successful sync; LiveView still falls back to client/list/events as before.
