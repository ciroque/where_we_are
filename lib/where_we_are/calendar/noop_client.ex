defmodule WhereWeAre.Calendar.NoopClient do
  @moduledoc """
  Minimal client implementation that returns no calendars or events.
  """

  @behaviour WhereWeAre.Calendar.Client

  @impl true
  def fetch_events(_config), do: {:ok, []}

  @impl true
  def list_calendars(_config), do: {:ok, []}
end
