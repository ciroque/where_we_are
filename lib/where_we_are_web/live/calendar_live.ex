defmodule WhereWeAreWeb.CalendarLive do
  use WhereWeAreWeb, :live_view

  def session(conn) do
    session = %{
      "tz" => conn.cookies["tz"] || "",
      "selected_calendars" => conn.cookies["selected_calendars"] || ""
    }

    case Plug.Conn.get_session(conn, "calendar_sync") do
      nil -> session
      name -> Map.put(session, "calendar_sync", name)
    end
  end

  @impl true
  def mount(params, session, socket) do
    timezone = resolve_timezone(session)
    today = DateTime.now!(timezone) |> DateTime.to_date()
    displayed_month = resolve_displayed_month(params, today)
    calendar_sync = resolve_calendar_sync(session)
    all_events = WhereWeAre.CalendarSync.events_for_month(calendar_sync, displayed_month)
    {known_calendars, calendar_colors} = fetch_known_calendars(calendar_sync, all_events)

    selected =
      case resolve_selected_calendars(session, known_calendars) do
        :all -> MapSet.new(known_calendars)
        names -> MapSet.new(names)
      end

    {:ok,
     socket
     |> assign(
       today: today,
       timezone: timezone,
       displayed_month: displayed_month,
       calendar_sync: calendar_sync,
       all_events: all_events,
       known_calendars: known_calendars,
       calendar_colors: calendar_colors,
       selected_calendars: selected,
       selected_event: nil,
       show_filter_notice: configured_calendars(calendar_sync) == []
     )
     |> assign_filtered_events(), layout: false}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    case params do
      %{"today" => "true"} ->
        month = Date.beginning_of_month(socket.assigns.today)
        {:noreply, load_month(socket, month)}

      %{"month" => month_param} ->
        month = parse_month(month_param, socket.assigns.today)
        {:noreply, load_month(socket, month)}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("prev_month", _, socket) do
    month = Date.shift(socket.assigns.displayed_month, month: -1)
    {:noreply, push_patch(socket, to: ~p"/?month=#{Date.to_iso8601(month)}")}
  end

  def handle_event("next_month", _, socket) do
    month = Date.shift(socket.assigns.displayed_month, month: 1)
    {:noreply, push_patch(socket, to: ~p"/?month=#{Date.to_iso8601(month)}")}
  end

  def handle_event("today", _, socket) do
    {:noreply, push_patch(socket, to: ~p"/?today=true")}
  end

  def handle_event("show_event", %{"uid" => uid}, socket) when is_binary(uid) do
    event = Enum.find(socket.assigns.events, fn e -> Map.get(e, :uid) == uid end)
    {:noreply, assign(socket, selected_event: event)}
  end

  def handle_event("show_event", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("close_event", _, socket) do
    {:noreply, assign(socket, selected_event: nil)}
  end

  def handle_event("close_filter_notice", _, socket) do
    {:noreply, assign(socket, show_filter_notice: false)}
  end

  def handle_event("toggle_calendar", %{"name" => name}, socket) do
    selected = socket.assigns.selected_calendars

    selected =
      if MapSet.member?(selected, name),
        do: MapSet.delete(selected, name),
        else: MapSet.put(selected, name)

    cookie_value = selected |> MapSet.to_list() |> Enum.join(",")

    {:noreply,
     socket
     |> assign(selected_calendars: selected)
     |> assign_filtered_events()
     |> push_event("persist_calendars", %{value: cookie_value})}
  end

  defp load_month(socket, month) do
    all_events = WhereWeAre.CalendarSync.events_for_month(socket.assigns.calendar_sync, month)

    socket
    |> assign(
      displayed_month: month,
      all_events: all_events
    )
    |> assign_filtered_events()
  end

  defp assign_filtered_events(socket) do
    %{all_events: all_events, selected_calendars: selected} = socket.assigns

    events =
      Enum.filter(all_events, fn event ->
        MapSet.member?(selected, Map.get(event, :calendar_name))
      end)

    selected_event =
      with %{uid: uid} <- socket.assigns.selected_event,
           event <- Enum.find(events, &(Map.get(&1, :uid) == uid)) do
        event
      else
        _ -> nil
      end

    socket
    |> assign(events: events)
    |> assign(selected_event: selected_event)
  end

  defp fetch_known_calendars(calendar_sync, all_events) do
    calendars_result = WhereWeAre.CalendarSync.list_calendars(calendar_sync)

    names =
      case calendars_result do
        {:ok, calendars} when is_list(calendars) and calendars != [] ->
          Enum.map(calendars, &calendar_name/1)

        {:ok, _calendars} ->
          derive_known_calendars(all_events)

        {:error, _reason} ->
          configured_calendars(calendar_sync) ++ derive_known_calendars(all_events)
      end
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> Enum.sort()

    colors = derive_calendar_colors(calendars_result, all_events)

    {names, colors}
  end

  defp derive_calendar_colors(calendars_result, all_events) do
    server_colors =
      case calendars_result do
        {:ok, calendars} when is_list(calendars) and calendars != [] ->
          calendars
          |> Enum.map(fn cal -> {calendar_name(cal), Map.get(cal, :color) || Map.get(cal, "color")} end)
          |> Enum.reject(fn {name, _color} -> is_nil(name) end)
          |> Map.new()

        _ ->
          %{}
      end

    event_colors =
      all_events
      |> Enum.flat_map(fn event ->
        case {Map.get(event, :calendar_name), Map.get(event, :calendar_color)} do
          {name, color} when is_binary(name) and not is_nil(color) -> [{name, color}]
          _ -> []
        end
      end)
      |> Map.new()

    Map.merge(event_colors, server_colors, fn _name, event_color, server_color -> server_color || event_color end)
  end

  defp configured_calendars(calendar_sync) do
    case WhereWeAre.CalendarSync.state(calendar_sync) do
      %{credentials: %{calendars: calendars}} when is_list(calendars) -> calendars
      _ -> []
    end
  end

  defp derive_known_calendars(events) do
    events
    |> Enum.map(&Map.get(&1, :calendar_name))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp calendar_name(%{display_name: name}) when is_binary(name), do: name
  defp calendar_name(%{"display_name" => name}) when is_binary(name), do: name
  defp calendar_name(_), do: nil

  defp resolve_selected_calendars(%{"selected_calendars" => saved}, known_calendars)
       when is_binary(saved) and saved != "" do
    names = String.split(saved, ",", trim: true)
    # Only keep names that are actually known to avoid stale entries
    valid = Enum.filter(names, &(&1 in known_calendars))
    if valid == [], do: :all, else: valid
  end

  defp resolve_selected_calendars(_session, _known_calendars), do: :all

  defp resolve_calendar_sync(%{"calendar_sync" => name}) when is_binary(name) do
    atom = String.to_existing_atom(name)

    case Process.whereis(atom) do
      nil -> WhereWeAre.CalendarSync
      _pid -> atom
    end
  rescue
    ArgumentError -> WhereWeAre.CalendarSync
  end

  defp resolve_calendar_sync(_session), do: WhereWeAre.CalendarSync

  defp resolve_timezone(%{"tz" => tz}) when is_binary(tz) and tz != "" do
    case DateTime.now(tz) do
      {:ok, _} -> tz
      _ -> "Etc/UTC"
    end
  end

  defp resolve_timezone(_session), do: "Etc/UTC"

  defp resolve_displayed_month(%{"month" => month_param}, today),
    do: parse_month(month_param, today)

  defp resolve_displayed_month(%{"today" => "true"}, today),
    do: Date.beginning_of_month(today)

  defp resolve_displayed_month(_params, today),
    do: Date.beginning_of_month(today)

  defp parse_month(month_param, today) do
    case Date.from_iso8601(month_param) do
      {:ok, date} -> Date.beginning_of_month(date)
      _error -> Date.beginning_of_month(today)
    end
  end

  # Template helpers used from the HEEx template
  def to_local(dtstart, timezone) do
    case dtstart do
      %DateTime{} = dt -> DateTime.shift_zone!(dt, timezone)
      other -> other
    end
  end

  def local_date(dtstart, timezone) do
    case dtstart do
      %DateTime{} = dt -> dt |> DateTime.shift_zone!(timezone) |> DateTime.to_date()
      %Date{} = d -> d
    end
  end
end
