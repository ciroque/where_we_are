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
            credentials: %{},
            last_sync: nil,
            last_error: nil,
            events: [],
            calendars: [],
            schedule?: true

  @type t :: %__MODULE__{}

  def new(opts) when is_list(opts) do
    %__MODULE__{
      client: Keyword.get(opts, :client, WhereWeAre.Calendar.NoopClient),
      name: Keyword.get(opts, :name, WhereWeAre.CalendarSync),
      poll_interval: Keyword.get(opts, :poll_interval, :timer.minutes(10)),
      event_window_months: Keyword.get(opts, :event_window_months, 6),
      expand_recurrences: Keyword.get(opts, :expand_recurrences, true),
      credentials: Keyword.get(opts, :credentials, %{}),
      events: Keyword.get(opts, :initial_events, []),
      calendars: Keyword.get(opts, :initial_calendars, []),
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

  def events_for_month(%__MODULE__{events: events}, month_start, timezone \\ "Etc/UTC") do
    Window.events_for_month(events, month_start, timezone)
  end

  def configured_calendars(%__MODULE__{credentials: credentials}) do
    case credentials do
      %{calendars: calendars} when is_list(calendars) -> calendars
      _ -> []
    end
  end

  def client_config(%__MODULE__{} = store) do
    store.credentials
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
      credentials: redact_credentials(store.credentials),
      last_sync: store.last_sync,
      last_error: store.last_error,
      events: store.events,
      calendars: store.calendars,
      configured_calendars: configured_calendars(store)
    }
  end

  defp redact_credentials(%{password: _} = credentials) do
    Map.put(credentials, :password, :redacted)
  end

  defp redact_credentials(credentials), do: credentials
end
