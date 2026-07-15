defmodule WhereWeAreWeb.CalendarLive do
  use WhereWeAreWeb, :live_view

  alias WhereWeAre.CalendarSync
  alias WhereWeAreWeb.Calendar.Assigns

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
    timezone = Assigns.resolve_timezone(session)
    today = DateTime.now!(timezone) |> DateTime.to_date()
    displayed_month = Assigns.resolve_displayed_month(params, today)
    calendar_sync = Assigns.resolve_calendar_sync(session)

    day_refresh_ref =
      if connected?(socket) do
        Phoenix.PubSub.subscribe(WhereWeAre.PubSub, CalendarSync.topic(calendar_sync))
        schedule_day_refresh(today, timezone)
      end

    all_events = CalendarSync.events_for_month(calendar_sync, displayed_month, timezone)
    {known_calendars, calendar_colors} = load_calendar_meta(calendar_sync, all_events)

    selected =
      session
      |> Assigns.resolve_selected_calendars(known_calendars)
      |> Assigns.selected_set(known_calendars)

    last_error = sync_last_error(calendar_sync)

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
       show_filter_notice: CalendarSync.configured_calendars(calendar_sync) == [],
       last_error: last_error,
       show_sync_error: last_error != nil,
       day_refresh_ref: day_refresh_ref
     )
     |> assign_filtered_events(), layout: false}
  end

  @impl true
  def handle_info(:day_changed, socket) do
    %{timezone: timezone, day_refresh_ref: old_ref} = socket.assigns
    if old_ref, do: Process.cancel_timer(old_ref)
    today = DateTime.now!(timezone) |> DateTime.to_date()
    ref = schedule_day_refresh(today, timezone)
    {:noreply, assign(socket, today: today, day_refresh_ref: ref)}
  end

  @impl true
  def handle_info(:events_updated, socket) do
    %{
      calendar_sync: calendar_sync,
      displayed_month: month,
      selected_calendars: selected,
      known_calendars: prev_known,
      timezone: timezone
    } = socket.assigns

    all_events = CalendarSync.events_for_month(calendar_sync, month, timezone)
    {known_calendars, calendar_colors} = load_calendar_meta(calendar_sync, all_events)
    selected = Assigns.merge_selected_with_new(selected, prev_known, known_calendars)
    last_error = sync_last_error(calendar_sync)

    {:noreply,
     socket
     |> assign(
       all_events: all_events,
       known_calendars: known_calendars,
       calendar_colors: calendar_colors,
       selected_calendars: selected,
       last_error: last_error,
       show_sync_error: last_error != nil
     )
     |> assign_filtered_events()}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    case params do
      %{"today" => "true"} ->
        month = Date.beginning_of_month(socket.assigns.today)
        {:noreply, load_month(socket, month)}

      %{"month" => month_param} ->
        month = Assigns.parse_month(month_param, socket.assigns.today)
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
    event = Enum.find(socket.assigns.events, &(&1.uid == uid))
    {:noreply, assign(socket, selected_event: event)}
  end

  def handle_event("show_event", _params, socket), do: {:noreply, socket}

  def handle_event("close_event", _, socket) do
    {:noreply, assign(socket, selected_event: nil)}
  end

  def handle_event("close_filter_notice", _, socket) do
    {:noreply, assign(socket, show_filter_notice: false)}
  end

  def handle_event("close_sync_error", _, socket) do
    {:noreply, assign(socket, show_sync_error: false)}
  end

  def handle_event("toggle_calendar", %{"name" => name}, socket) do
    selected = Assigns.toggle_calendar(socket.assigns.selected_calendars, name)
    cookie_value = selected |> MapSet.to_list() |> Enum.join(",")

    {:noreply,
     socket
     |> assign(selected_calendars: selected)
     |> assign_filtered_events()
     |> push_event("persist_calendars", %{value: cookie_value})}
  end

  defp load_month(socket, month) do
    %{
      calendar_sync: calendar_sync,
      calendar_colors: existing_colors,
      timezone: timezone
    } = socket.assigns

    all_events = CalendarSync.events_for_month(calendar_sync, month, timezone)
    new_colors = Assigns.calendar_colors({:ok, []}, all_events)

    socket
    |> assign(
      displayed_month: month,
      all_events: all_events,
      calendar_colors: Assigns.merge_colors(existing_colors, new_colors)
    )
    |> assign_filtered_events()
  end

  defp assign_filtered_events(socket) do
    events =
      Assigns.filter_events(socket.assigns.all_events, socket.assigns.selected_calendars)

    selected_event = Assigns.retain_selected_event(events, socket.assigns.selected_event)

    socket
    |> assign(events: events)
    |> assign(selected_event: selected_event)
  end

  defp load_calendar_meta(calendar_sync, all_events) do
    calendars_result = CalendarSync.list_calendars(calendar_sync)

    known =
      Assigns.known_calendars(calendars_result, all_events, fn ->
        CalendarSync.configured_calendars(calendar_sync)
      end)

    {known, Assigns.calendar_colors(calendars_result, all_events)}
  end

  defp sync_last_error(calendar_sync) do
    case CalendarSync.state(calendar_sync) do
      %{last_error: error} -> error
      _ -> nil
    end
  end

  defp schedule_day_refresh(today, timezone) do
    Process.send_after(self(), :day_changed, Assigns.ms_until_midnight(today, timezone))
  end
end
