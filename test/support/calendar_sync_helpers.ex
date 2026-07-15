defmodule WhereWeAre.CalendarSyncHelpers do
  @moduledoc false

  alias WhereWeAre.CalendarSync.Store

  @doc """
  Test-only helper to replace stored events via `:sys.replace_state/2`.

  Prefer this over shipping a compile-time `Mix.env() == :test` GenServer API.
  """
  def put_events(server, events) when is_list(events) do
    :sys.replace_state(server, fn store ->
      Store.put_events(store, events)
    end)

    :ok
  end
end
