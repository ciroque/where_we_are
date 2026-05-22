defmodule WhereWeAre.CalendarSync do
  use GenServer

  @default_poll_interval :timer.minutes(10)

  defmodule NoopClient do
    def fetch_events(_config), do: {:ok, []}
  end

  defstruct client: nil,
            poll_interval: @default_poll_interval,
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

  @impl true
  def init(opts) do
    state = %__MODULE__{
      client: Keyword.get(opts, :client, NoopClient),
      poll_interval: Keyword.get(opts, :poll_interval, @default_poll_interval),
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

  @impl true
  def handle_info(:sync, state) do
    {_reply, state} = sync(state)

    if state.schedule? do
      Process.send_after(self(), :sync, state.poll_interval)
    end

    {:noreply, state}
  end

  defp sync(state) do
    case state.client.fetch_events(state.credentials) do
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
      credentials: state.credentials,
      last_sync: state.last_sync,
      last_error: state.last_error,
      events: state.events
    }
  end
end
