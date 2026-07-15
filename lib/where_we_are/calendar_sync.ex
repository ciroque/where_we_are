defmodule WhereWeAre.CalendarSync do
  @moduledoc """
  Manages and schedules the CalDAV synchronization process, exposing sync state and controls.
  """
  use GenServer

  alias WhereWeAre.CalendarSync.Store

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
    case store.calendars do
      calendars when is_list(calendars) ->
        {:reply, {:ok, calendars}, store}

      nil ->
        case store.client.list_calendars(store.credentials) do
          {:ok, calendars} when is_list(calendars) ->
            {:reply, {:ok, calendars}, %{store | calendars: calendars}}

          other ->
            {:reply, other, store}
        end
    end
  end

  def handle_call(:configured_calendars, _from, store) do
    {:reply, Store.configured_calendars(store), store}
  end

  def handle_call({:events_for_month, month_start, timezone}, _from, store) do
    {:reply, Store.events_for_month(store, month_start, timezone), store}
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
        store =
          store
          |> maybe_load_calendars()
          |> Store.put_events(events)

        Phoenix.PubSub.broadcast(WhereWeAre.PubSub, topic(store.name), :events_updated)
        {{:ok, events}, store}

      {:error, reason} ->
        store = Store.put_error(store, reason)
        {{:error, reason}, store}
    end
  end

  # Only hit the remote list_calendars endpoint when we have not fetched yet.
  # Cached lists (including empty) are kept until process restart / explicit refresh.
  defp maybe_load_calendars(%{calendars: calendars} = store) when is_list(calendars), do: store

  defp maybe_load_calendars(store) do
    case store.client.list_calendars(store.credentials) do
      {:ok, list} when is_list(list) -> %{store | calendars: list}
      _ -> store
    end
  end
end
