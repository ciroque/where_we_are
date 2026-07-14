defmodule WhereWeAreWeb.CalendarHelpers do
  @moduledoc """
  Shared date/time helpers for calendar rendering.
  """

  def to_local(%DateTime{} = dt, timezone), do: DateTime.shift_zone!(dt, timezone)
  def to_local(other, _timezone), do: other

  def local_date(%DateTime{} = dt, timezone) do
    dt |> DateTime.shift_zone!(timezone) |> DateTime.to_date()
  end

  def local_date(%Date{} = date, _timezone), do: date

  def event_dates(event, timezone, grid_start \\ nil, grid_end \\ nil) do
    start = local_date(event.dtstart, timezone)
    finish = event_finish_date(event, timezone, start)
    start = clamp_date(start, grid_start, :min)
    finish = clamp_date(finish, grid_end, :max)
    date_range(start, finish)
  end

  def event_end_date(event, timezone) do
    start = local_date(event.dtstart, timezone)
    event_finish_date(event, timezone, start)
  end

  defp event_finish_date(event, timezone, start) do
    finish =
      case Map.get(event, :dtend) do
        nil ->
          start

        %Date{} = date ->
          Date.add(date, -1)

        %DateTime{} = dt ->
          dt |> DateTime.shift_zone!(timezone) |> DateTime.add(-1, :second) |> DateTime.to_date()

        _other ->
          start
      end

    if Date.compare(start, finish) == :gt, do: start, else: finish
  end

  defp clamp_date(date, nil, _direction), do: date

  defp clamp_date(date, bound, :min) do
    if Date.compare(date, bound) == :lt, do: bound, else: date
  end

  defp clamp_date(date, bound, :max) do
    if Date.compare(date, bound) == :gt, do: bound, else: date
  end

  defp date_range(start, finish) do
    if Date.compare(start, finish) == :gt, do: [], else: Date.range(start, finish) |> Enum.to_list()
  end
end
