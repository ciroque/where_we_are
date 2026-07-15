defmodule WhereWeAreWeb.Calendar.ViewModel do
  @moduledoc """
  Pure view-model builders for calendar rendering.
  """

  alias WhereWeAre.Calendar.Window

  def month_grid(displayed_month, events, timezone) do
    first_of_month = Date.beginning_of_month(displayed_month)
    month_label = Calendar.strftime(first_of_month, "%B %Y")
    sunday_offset = rem(Date.day_of_week(first_of_month), 7)
    grid_start = Date.add(first_of_month, -sunday_offset)
    grid_end = Date.add(grid_start, 41)
    cells = Enum.map(0..41, fn offset -> Date.add(grid_start, offset) end)

    events_by_date =
      events
      |> Enum.flat_map(fn event ->
        event
        |> Window.days_in_range(timezone, grid_start, grid_end)
        |> Enum.map(fn date -> {date, event} end)
      end)
      |> Enum.group_by(fn {date, _event} -> date end, fn {_date, event} -> event end)

    %{
      first_of_month: first_of_month,
      month_label: month_label,
      cells: cells,
      events_by_date: events_by_date
    }
  end

  def agenda(events, today, timezone) do
    {past_events, upcoming_events} = Window.split_past_upcoming(events, today, timezone)
    %{past_events: past_events, upcoming_events: upcoming_events}
  end
end
