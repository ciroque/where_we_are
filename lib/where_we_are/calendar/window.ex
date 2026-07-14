defmodule WhereWeAre.Calendar.Window do
  @moduledoc """
  Pure date/time rules for calendar events.

  Owns exclusive iCalendar-style end handling, range overlap, grid day expansion,
  chronological sort keys, and past/upcoming splits.
  """

  @doc """
  Returns the inclusive local end date for an event.

  iCalendar `DTEND` is exclusive:
  - `%Date{}` ends are shifted back one day
  - `%DateTime{}` ends are shifted back one second before converting to a date
  """
  def end_date(event, timezone \\ "Etc/UTC") do
    start = local_date(event_start(event), timezone)

    if is_nil(start) do
      raise ArgumentError, "calendar event is missing or has an invalid :dtstart"
    end

    finish = finish_date(event, timezone, start)
    if Date.compare(start, finish) == :gt, do: start, else: finish
  end

  @doc """
  True when the event overlaps the inclusive `[range_start, range_end]` date range.
  """
  def overlaps_range?(event, range_start, range_end) do
    case {start_date(event), exclusive_end_as_inclusive(event)} do
      {{:ok, start_date}, {:ok, end_date}} ->
        end_date = if Date.compare(end_date, start_date) == :lt, do: start_date, else: end_date

        Date.compare(start_date, range_end) in [:eq, :lt] and
          Date.compare(end_date, range_start) in [:eq, :gt]

      _ ->
        false
    end
  end

  @doc """
  Events whose range overlaps the calendar month of `month_start`.
  """
  def events_for_month(events, month_start) when is_list(events) do
    month_start = Date.beginning_of_month(month_start)
    month_end = Date.end_of_month(month_start)

    events
    |> Enum.filter(&overlaps_range?(&1, month_start, month_end))
    |> Enum.sort_by(&sort_key/1, fn left, right -> DateTime.compare(left, right) != :gt end)
  end

  @doc """
  Inclusive local dates the event occupies, optionally clamped to a grid window.
  """
  def days_in_range(event, timezone, grid_start \\ nil, grid_end \\ nil) do
    start = local_date(event_start(event), timezone)

    if is_nil(start) do
      raise ArgumentError, "calendar event is missing or has an invalid :dtstart"
    end

    finish = end_date(event, timezone)
    start = clamp_date(start, grid_start, :min)
    finish = clamp_date(finish, grid_end, :max)
    date_range(start, finish)
  end

  @doc """
  Chronological sort key for an event start.
  """
  def sort_key(%{dtstart: %DateTime{} = dt}), do: dt

  def sort_key(%{dtstart: %Date{} = date}),
    do: DateTime.new!(date, ~T[00:00:00], "Etc/UTC")

  def sort_key(_event), do: DateTime.new!(~D[0000-01-01], ~T[00:00:00], "Etc/UTC")

  @doc """
  Split events into `{past, upcoming}` relative to local `today`.

  An event is past when its inclusive end date is strictly before `today`.
  """
  def split_past_upcoming(events, today, timezone \\ "Etc/UTC") when is_list(events) do
    Enum.split_with(events, fn event ->
      Date.compare(end_date(event, timezone), today) == :lt
    end)
  end

  @doc """
  Shift a DateTime into `timezone`, or return non-DateTime values unchanged.
  """
  def to_local(%DateTime{} = dt, timezone), do: DateTime.shift_zone!(dt, timezone)
  def to_local(other, _timezone), do: other

  @doc """
  Local calendar date for a DateTime or Date start value.
  """
  def local_date(%DateTime{} = dt, timezone) do
    dt |> DateTime.shift_zone!(timezone) |> DateTime.to_date()
  end

  def local_date(%Date{} = date, _timezone), do: date
  def local_date(_other, _timezone), do: nil

  defp event_start(%{dtstart: dtstart}), do: dtstart
  defp event_start(_event), do: nil

  defp start_date(%{dtstart: %DateTime{} = dt}), do: {:ok, DateTime.to_date(dt)}
  defp start_date(%{dtstart: %Date{} = date}), do: {:ok, date}
  defp start_date(_event), do: :error

  # Date-only form used for month filtering (matches historical CalendarSync behavior).
  defp exclusive_end_as_inclusive(event) do
    case Map.get(event, :dtend) do
      nil ->
        start_date(event)

      %Date{} = date ->
        {:ok, Date.add(date, -1)}

      %DateTime{} = dt ->
        {:ok, dt |> DateTime.add(-1, :second) |> DateTime.to_date()}

      _other ->
        :error
    end
  end

  defp finish_date(event, timezone, start) do
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
