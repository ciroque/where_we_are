defmodule WhereWeAre.CalendarSyncHelpers do
  @moduledoc false

  @doc """
  Test-only helper to replace stored events without a Mix.env compile branch.
  """
  def put_events(server, events) when is_list(events) do
    :sys.replace_state(server, fn store ->
      %{store | events: events}
    end)

    :ok
  end
end
