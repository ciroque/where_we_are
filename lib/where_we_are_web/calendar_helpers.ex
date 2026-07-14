defmodule WhereWeAreWeb.CalendarHelpers do
  @moduledoc """
  Web façade over `WhereWeAre.Calendar.Window` for templates and LiveViews.
  """

  alias WhereWeAre.Calendar.Window

  def to_local(value, timezone), do: Window.to_local(value, timezone)

  def local_date(value, timezone), do: Window.local_date(value, timezone)

  def event_dates(event, timezone, grid_start \\ nil, grid_end \\ nil) do
    Window.days_in_range(event, timezone, grid_start, grid_end)
  end

  def event_end_date(event, timezone), do: Window.end_date(event, timezone)
end
