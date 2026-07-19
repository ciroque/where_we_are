defmodule WhereWeAre.CalendarSync.Store do
  @moduledoc """
  Pure in-memory calendar sync state.

  The GenServer holds a `%Store{}` and delegates query/update logic here so
  month filtering and public status can be unit-tested without OTP.
  """

  alias WhereWeAre.Calendar.Window

  @enforce_keys [:client]
  defstruct client: nil,
            name: WhereWeAre.CalendarSync,
            poll_interval: :timer.minutes(10),
            event_window_months: 6,
            expand_recurrences: true,
            auth: %{},
            server: %{},
            filter: %{},
            # Legacy keyword still accepted via `credentials:` for tests and older config.
            credentials: %{},
            last_sync: nil,
            last_error: nil,
            events: [],
            # nil = not yet fetched; [] = fetched and empty
            calendars: nil,
            schedule?: true

  @type t :: %__MODULE__{}

  def new(opts) when is_list(opts) do
    {auth, server, filter, credentials} = connection_parts(opts)

    %__MODULE__{
      client: Keyword.get(opts, :client, WhereWeAre.Calendar.NoopClient),
      name: Keyword.get(opts, :name, WhereWeAre.CalendarSync),
      poll_interval: Keyword.get(opts, :poll_interval, :timer.minutes(10)),
      event_window_months: Keyword.get(opts, :event_window_months, 6),
      expand_recurrences: Keyword.get(opts, :expand_recurrences, true),
      auth: auth,
      server: server,
      filter: filter,
      credentials: credentials,
      events: Keyword.get(opts, :initial_events, []),
      calendars: Keyword.get(opts, :initial_calendars, nil),
      schedule?: Keyword.get(opts, :schedule?, true)
    }
  end

  def put_events(%__MODULE__{} = store, events, opts \\ []) when is_list(events) do
    calendars = Keyword.get(opts, :calendars, store.calendars)

    %{
      store
      | events: events,
        calendars: calendars,
        last_sync: DateTime.utc_now(),
        last_error: nil
    }
  end

  def put_error(%__MODULE__{} = store, reason) do
    %{store | last_error: reason}
  end

  @doc """
  Applies reloadable filter/window settings (e.g. after ConfigMap file changes).

  When the calendar name filter changes, clears the cached catalog so the next
  list/sync re-discovers under the new filter.
  """
  def apply_runtime_config(%__MODULE__{} = store, opts) when is_list(opts) do
    filter = Keyword.get(opts, :filter, store.filter)
    event_window_months = Keyword.get(opts, :event_window_months, store.event_window_months)
    filter_changed? = filter != store.filter

    # Keep legacy credentials map aligned (drop stale :calendars when filter clears).
    credentials =
      store.credentials
      |> Map.drop([:calendars])
      |> Map.merge(filter)

    store = %{
      store
      | filter: filter,
        event_window_months: event_window_months,
        credentials: credentials
    }

    if filter_changed? do
      %{store | calendars: nil, events: []}
    else
      store
    end
  end

  def events_for_month(%__MODULE__{events: events}, month_start, timezone \\ "Etc/UTC") do
    Window.events_for_month(events, month_start, timezone)
  end

  def configured_calendars(%__MODULE__{filter: filter, credentials: credentials}) do
    cond do
      is_list(Map.get(filter, :calendars)) -> Map.get(filter, :calendars)
      is_list(Map.get(credentials, :calendars)) -> Map.get(credentials, :calendars)
      true -> []
    end
  end

  @doc """
  Flat config map consumed by calendar clients (auth + server + filter + sync knobs).
  """
  def client_config(%__MODULE__{} = store) do
    store.credentials
    |> Map.merge(store.auth)
    |> Map.merge(store.server)
    |> Map.merge(store.filter)
    |> Map.put(:event_window_months, store.event_window_months)
    |> Map.put(:expand_recurrences, store.expand_recurrences)
  end

  @doc """
  Public status snapshot. Never includes the CalDAV password.
  """
  def public_status(%__MODULE__{} = store) do
    %{
      client: store.client,
      poll_interval: store.poll_interval,
      event_window_months: store.event_window_months,
      expand_recurrences: store.expand_recurrences,
      credentials: redact_credentials(connection_credentials(store)),
      last_sync: store.last_sync,
      last_error: store.last_error,
      events: store.events,
      calendars: store.calendars,
      configured_calendars: configured_calendars(store)
    }
  end

  defp connection_credentials(%__MODULE__{} = store) do
    store.credentials
    |> Map.merge(store.auth)
    |> Map.merge(store.server)
    |> Map.merge(store.filter)
  end

  defp connection_parts(opts) do
    credentials = Keyword.get(opts, :credentials, %{})
    auth = Keyword.get(opts, :auth, Map.take(credentials, [:username, :password]))
    server = Keyword.get(opts, :server, Map.take(credentials, [:url]))
    filter = Keyword.get(opts, :filter, Map.take(credentials, [:calendars]))

    # Keep a credentials map for backwards-compatible tests that only pass credentials.
    merged =
      credentials
      |> Map.merge(auth)
      |> Map.merge(server)
      |> Map.merge(filter)

    {auth, server, filter, merged}
  end

  defp redact_credentials(%{password: _} = credentials) do
    Map.put(credentials, :password, :redacted)
  end

  defp redact_credentials(credentials), do: credentials
end
