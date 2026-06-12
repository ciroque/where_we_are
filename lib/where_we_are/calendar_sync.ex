defmodule WhereWeAre.CalendarSync do
  @moduledoc """
  Manages and schedules the CalDAV synchronization process, exposing sync state and controls.
  """
  use GenServer

  @default_poll_interval :timer.minutes(10)

  defmodule NoopClient do
    @moduledoc """
    Minimal client implementation that returns no events for testing and defaults.
    """
    def fetch_events(_config), do: {:ok, []}
  end

  defstruct client: nil,
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

  def handle_call({:events_for_month, month_start}, _from, state) do
    month_start = Date.beginning_of_month(month_start)
    month_end = Date.end_of_month(month_start)

    events =
      state.events
      |> Enum.filter(&event_in_range?(&1, month_start, month_end))
      |> Enum.sort_by(&event_sort_key/1, fn left, right ->
        DateTime.compare(left, right) != :gt
      end)

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

  defp event_in_range?(event, month_start, month_end) do
    case event_date(event) do
      {:ok, date} ->
        Date.compare(date, month_start) in [:eq, :gt] and
          Date.compare(date, month_end) in [:eq, :lt]

      _ ->
        false
    end
  end

  defp event_sort_key(%{dtstart: %DateTime{} = dt}), do: dt

  defp event_sort_key(%{dtstart: %Date{} = date}),
    do: DateTime.new!(date, ~T[00:00:00], "Etc/UTC")

  defp event_sort_key(_event), do: DateTime.new!(~D[0000-01-01], ~T[00:00:00], "Etc/UTC")

  defp event_date(%{dtstart: %DateTime{} = dt}), do: {:ok, DateTime.to_date(dt)}
  defp event_date(%{dtstart: %Date{} = date}), do: {:ok, date}
  defp event_date(_event), do: :error
end
