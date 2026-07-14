defmodule WhereWeAre.CalendarSync do
  @moduledoc """
  Manages and schedules the CalDAV synchronization process, exposing sync state and controls.
  """
  use GenServer

  alias WhereWeAre.Calendar.Window

  @default_poll_interval :timer.minutes(10)

  defmodule NoopClient do
    @moduledoc """
    Minimal client implementation that returns no events for testing and defaults.
    """
    def fetch_events(_config), do: {:ok, []}
    def list_calendars(_config), do: {:ok, []}
  end

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

  def events_for_month(month_start) do
    events_for_month(__MODULE__, month_start)
  end

  def events_for_month(server, month_start) do
    GenServer.call(server, {:events_for_month, month_start})
  end

  @impl true
  def init(opts) do
    state = %__MODULE__{
      client: Keyword.get(opts, :client, NoopClient),
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

    {:ok, state}
  end

  @impl true
  def handle_call(:sync_now, _from, state) do
    {reply, state} = sync(state)
    {:reply, reply, state}
  end

  def handle_call(:state, _from, state) do
    {:reply, public_state(state), state}
  end

  def handle_call(:list_calendars, _from, state) do
    reply = state.client.list_calendars(state.credentials)
    {:reply, reply, state}
  end

  if Mix.env() == :test do
    def handle_call({:set_events, events}, _from, state) when is_list(events) do
      {:reply, :ok, %{state | events: events}}
    end
  end

  def handle_call({:events_for_month, month_start}, _from, state) do
    events = Window.events_for_month(state.events, month_start)
    {:reply, events, state}
  end

  @impl true
  def handle_info(:sync, state) do
    {_reply, state} = sync(state)

    if state.schedule? do
      Process.send_after(self(), :sync, state.poll_interval)
    end

    {:noreply, state}
  end

  defp sync(state) do
    config =
      state.credentials
      |> Map.put(:event_window_months, state.event_window_months)
      |> Map.put(:expand_recurrences, state.expand_recurrences)

    case state.client.fetch_events(config) do
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
