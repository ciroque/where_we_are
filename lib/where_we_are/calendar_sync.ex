defmodule WhereWeAre.CalendarSync do
  @moduledoc """
  Manages and schedules the CalDAV synchronization process, exposing sync state and controls.
  """
  use GenServer

  alias WhereWeAre.Calendar.Window

  @default_poll_interval :timer.minutes(10)

  defstruct client: nil,
            name: nil,
            poll_interval: @default_poll_interval,
            event_window_months: 6,
            expand_recurrences: true,
            credentials: %{},
            last_sync: nil,
            last_error: nil,
            events: [],
            schedule?: true

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def topic(server \\ __MODULE__) do
    server_id = if is_atom(server), do: Atom.to_string(server), else: inspect(server)
    "calendar_sync:" <> server_id
  end

  def sync_now(server \\ __MODULE__) do
    GenServer.call(server, :sync_now)
  end

  def state(server \\ __MODULE__) do
    GenServer.call(server, :state)
  end

  def list_calendars(server \\ __MODULE__) do
    GenServer.call(server, :list_calendars)
  end

  def configured_calendars(server \\ __MODULE__) do
    GenServer.call(server, :configured_calendars)
  end

  def events_for_month(month_start) do
    events_for_month(__MODULE__, month_start, "Etc/UTC")
  end

  def events_for_month(server, month_start) do
    events_for_month(server, month_start, "Etc/UTC")
  end

  def events_for_month(server, month_start, timezone) when is_binary(timezone) do
    GenServer.call(server, {:events_for_month, month_start, timezone})
  end

  @impl true
  def init(opts) do
    state = %__MODULE__{
      client: Keyword.get(opts, :client, WhereWeAre.Calendar.NoopClient),
      name: Keyword.get(opts, :name, __MODULE__),
      poll_interval: Keyword.get(opts, :poll_interval, @default_poll_interval),
      event_window_months: Keyword.get(opts, :event_window_months, 6),
      expand_recurrences: Keyword.get(opts, :expand_recurrences, true),
      credentials: Keyword.get(opts, :credentials, %{}),
      events: Keyword.get(opts, :initial_events, []),
      schedule?: Keyword.get(opts, :schedule?, true)
    }

    if state.schedule? do
      Process.send_after(self(), :sync, 0)
    end

    {:ok, store}
  end

  @impl true
  def handle_call(:sync_now, _from, store) do
    {reply, store} = sync(store)
    {:reply, reply, store}
  end

  def handle_call(:state, _from, store) do
    {:reply, Store.public_status(store), store}
  end

  def handle_call(:list_calendars, _from, store) do
    reply =
      case store.calendars do
        calendars when is_list(calendars) and calendars != [] ->
          {:ok, calendars}

        _ ->
          store.client.list_calendars(store.credentials)
      end

  def handle_call({:events_for_month, month_start, timezone}, _from, state) do
    events = Window.events_for_month(state.events, month_start, timezone)
    {:reply, events, state}
  end

  @impl true
  def handle_info(:sync, store) do
    {_reply, store} = sync(store)

    if store.schedule? do
      Process.send_after(self(), :sync, store.poll_interval)
    end

    {:noreply, store}
  end

  defp sync(store) do
    config = Store.client_config(store)

    case store.client.fetch_events(config) do
      {:ok, events} ->
        state = %{state | events: events, last_sync: DateTime.utc_now(), last_error: nil}
        Phoenix.PubSub.broadcast(WhereWeAre.PubSub, topic(state.name), :events_updated)
        {{:ok, events}, state}

      {:error, reason} ->
        state = %{state | last_error: reason}
        {{:error, reason}, state}
    end
  end

  defp public_state(state) do
    %{
      client: state.client,
      poll_interval: state.poll_interval,
      event_window_months: state.event_window_months,
      expand_recurrences: state.expand_recurrences,
      credentials: state.credentials,
      last_sync: state.last_sync,
      last_error: state.last_error,
      events: state.events
    }
  end
end
