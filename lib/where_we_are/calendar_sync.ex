defmodule WhereWeAre.CalendarSync do
  @moduledoc """
  OTP boundary for calendar synchronization.

  Schedules CalDAV polls, stores the latest successful event list, caches
  calendar metadata, and broadcasts `:events_updated` on PubSub.

  Prefer `configured_calendars/1` and redacted `state/1` over digging into
  connection secrets. Password values are never returned from `state/1`.
  """
  use GenServer

  alias WhereWeAre.CalendarSync.Store

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc "PubSub topic for a given sync server name or pid."
  def topic(server \\ __MODULE__) do
    server_id = if is_atom(server), do: Atom.to_string(server), else: inspect(server)
    "calendar_sync:" <> server_id
  end

  @doc "Force an immediate sync."
  def sync_now(server \\ __MODULE__) do
    GenServer.call(server, :sync_now)
  end

  @doc "Redacted public status (password never included)."
  def state(server \\ __MODULE__) do
    GenServer.call(server, :state)
  end

  @doc "Cached calendar catalog when available, otherwise live client list."
  def list_calendars(server \\ __MODULE__) do
    GenServer.call(server, :list_calendars)
  end

  @doc "Configured `CALDAV_CALENDARS` allow-list (may be empty)."
  def configured_calendars(server \\ __MODULE__) do
    GenServer.call(server, :configured_calendars)
  end

  def events_for_month(month_start) do
    events_for_month(__MODULE__, month_start)
  end

  @doc "Events overlapping the calendar month of `month_start`."
  def events_for_month(server, month_start) do
    GenServer.call(server, {:events_for_month, month_start})
  end

  @impl true
  def init(opts) do
    store = Store.new(opts)

    if store.schedule? do
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
          store.client.list_calendars(Store.client_config(store))
      end

    {:reply, reply, store}
  end

  def handle_call(:configured_calendars, _from, store) do
    {:reply, Store.configured_calendars(store), store}
  end

  def handle_call({:events_for_month, month_start}, _from, store) do
    {:reply, Store.events_for_month(store, month_start), store}
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
        calendars =
          case store.client.list_calendars(config) do
            {:ok, list} when is_list(list) -> list
            _ -> store.calendars
          end

        store = Store.put_events(store, events, calendars: calendars)
        Phoenix.PubSub.broadcast(WhereWeAre.PubSub, topic(store.name), :events_updated)
        {{:ok, events}, store}

      {:error, reason} ->
        store = Store.put_error(store, reason)
        Phoenix.PubSub.broadcast(WhereWeAre.PubSub, topic(store.name), :events_updated)
        {{:error, reason}, store}
    end
  end
end
