defmodule WhereWeAreWeb.Calendar.Assigns do
  @moduledoc """
  Helpers for building CalendarLive assigns from params/session.
  """

  def resolve_timezone(%{"tz" => tz}) when is_binary(tz) and tz != "" do
    case DateTime.now(tz) do
      {:ok, _} -> tz
      _ -> "Etc/UTC"
    end
  end

  def resolve_timezone(_session), do: "Etc/UTC"

  def resolve_displayed_month(%{"month" => month_param}, today),
    do: parse_month(month_param, today)

  def resolve_displayed_month(%{"today" => "true"}, today),
    do: Date.beginning_of_month(today)

  def resolve_displayed_month(_params, today),
    do: Date.beginning_of_month(today)

  def parse_month(month_param, today) when is_binary(month_param) do
    case Date.from_iso8601(month_param) do
      {:ok, date} -> Date.beginning_of_month(date)
      _error -> Date.beginning_of_month(today)
    end
  end

  def parse_month(_month_param, today), do: Date.beginning_of_month(today)

  def resolve_selected_calendars(%{"selected_calendars" => saved}, known_calendars)
      when is_binary(saved) and saved != "" do
    names = String.split(saved, ",", trim: true)
    valid = Enum.filter(names, &(&1 in known_calendars))
    if valid == [], do: :all, else: valid
  end

  def resolve_selected_calendars(_session, _known_calendars), do: :all

  def selected_set(:all, known_calendars), do: MapSet.new(known_calendars)
  def selected_set(names, _known_calendars) when is_list(names), do: MapSet.new(names)

  def filter_events(all_events, selected_calendars) do
    Enum.filter(all_events, fn event ->
      MapSet.member?(selected_calendars, event.calendar_name)
    end)
  end

  def retain_selected_event(events, %{uid: uid}) do
    Enum.find(events, &(&1.uid == uid))
  end

  def retain_selected_event(_events, _selected), do: nil

  def merge_selected_with_new(selected, prev_known, known_calendars) do
    prev_known_set = MapSet.new(prev_known)
    new_calendars = Enum.reject(known_calendars, &MapSet.member?(prev_known_set, &1))
    MapSet.union(selected, MapSet.new(new_calendars))
  end

  def toggle_calendar(selected, name) do
    if MapSet.member?(selected, name),
      do: MapSet.delete(selected, name),
      else: MapSet.put(selected, name)
  end

  def known_calendars(calendars_result, all_events, configured_calendars) do
    names =
      case calendars_result do
        {:ok, calendars} when is_list(calendars) and calendars != [] ->
          Enum.map(calendars, &calendar_name/1)

        {:ok, _calendars} ->
          derive_known_calendars(all_events)

        {:error, _reason} ->
          configured_calendars ++ derive_known_calendars(all_events)
      end

    names
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  def calendar_colors(calendars_result, all_events) do
    server_colors =
      case calendars_result do
        {:ok, calendars} when is_list(calendars) and calendars != [] ->
          calendars
          |> Enum.map(fn cal ->
            {calendar_name(cal), Map.get(cal, :color) || Map.get(cal, "color")}
          end)
          |> Enum.reject(fn {name, _color} -> is_nil(name) end)
          |> Map.new()

        _ ->
          %{}
      end

    event_colors =
      all_events
      |> Enum.flat_map(fn event ->
        case {event.calendar_name, event.calendar_color} do
          {name, color} when is_binary(name) and not is_nil(color) -> [{name, color}]
          _ -> []
        end
      end)
      |> Map.new()

    Map.merge(event_colors, server_colors, fn _name, event_color, server_color ->
      server_color || event_color
    end)
  end

  def merge_colors(existing, new) do
    Map.merge(existing, new, fn _k, old, next -> next || old end)
  end

  def resolve_calendar_sync(%{"calendar_sync" => name}) when is_binary(name) do
    atom = String.to_existing_atom(name)

    case Process.whereis(atom) do
      nil -> WhereWeAre.CalendarSync
      _pid -> atom
    end
  rescue
    ArgumentError -> WhereWeAre.CalendarSync
  end

  def resolve_calendar_sync(_session), do: WhereWeAre.CalendarSync

  def ms_until_midnight(today, timezone) do
    now = DateTime.now!(timezone)
    tomorrow = Date.add(today, 1)

    midnight =
      case DateTime.new(tomorrow, ~T[00:00:00], timezone) do
        {:ok, dt} -> dt
        {:ambiguous, dt, _} -> dt
        {:gap, _, dt} -> dt
      end

    max(0, DateTime.diff(midnight, now, :millisecond))
  end

  defp derive_known_calendars(events) do
    events
    |> Enum.map(& &1.calendar_name)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp calendar_name(%{display_name: name}) when is_binary(name), do: name
  defp calendar_name(%{"display_name" => name}) when is_binary(name), do: name
  defp calendar_name(_), do: nil
end
