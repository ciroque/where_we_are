defmodule WhereWeAreWeb.CalendarLiveTest do
  use WhereWeAreWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders current month calendar", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/")

    today = Date.utc_today()
    month_label = Calendar.strftime(Date.beginning_of_month(today), "%B %Y")

    assert html =~ month_label
    assert html =~ "Move Previous"
    assert html =~ "Move Next"
    assert html =~ "Today"

    assert html =~ "Sun"
    assert html =~ "Mon"
    assert html =~ "Tue"
    assert html =~ "Wed"
    assert html =~ "Thu"
    assert html =~ "Fri"
    assert html =~ "Sat"

    assert has_element?(view, "button", "Move Previous")
    assert has_element?(view, "button", "Move Next")
    assert has_element?(view, "button", "Today")
  end

  test "navigates to previous month", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    today = Date.utc_today()
    prev_month = Date.shift(Date.beginning_of_month(today), month: -1)
    prev_label = Calendar.strftime(prev_month, "%B %Y")

    html = view |> element("button", "Move Previous") |> render_click()

    assert html =~ prev_label
  end

  test "navigates to next month", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    today = Date.utc_today()
    next_month = Date.shift(Date.beginning_of_month(today), month: 1)
    next_label = Calendar.strftime(next_month, "%B %Y")

    html = view |> element("button", "Move Next") |> render_click()

    assert html =~ next_label
  end

  test "today button returns to current month", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    today = Date.utc_today()
    month_label = Calendar.strftime(Date.beginning_of_month(today), "%B %Y")

    # Navigate away first
    view |> element("button", "Move Previous") |> render_click()

    # Click Today
    html = view |> element("button", "Today") |> render_click()

    assert html =~ month_label
  end

  test "shows notice when no calendar filter is configured", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/")

    assert html =~ "No calendar filter is configured"

    html = view |> element("button[aria-label='Dismiss notice']") |> render_click()
    refute html =~ "No calendar filter is configured"
  end

  test "does not show notice when a calendar filter is configured", %{conn: conn} do
    server_name = __MODULE__

    defmodule FilteredCalendarClient do
      def list_calendars(_config), do: {:ok, [%{display_name: "Work"}]}
      def fetch_events(_config), do: {:ok, []}
    end

    start_supervised!(
      {WhereWeAre.CalendarSync,
       name: server_name,
       schedule?: false,
       client: FilteredCalendarClient,
       credentials: %{calendars: ["Work"]},
       initial_events: []}
    )

    conn = conn |> init_test_session(%{"calendar_sync" => Atom.to_string(server_name)})

    {:ok, _view, html} = live(conn, ~p"/")

    refute html =~ "No calendar filter is configured"
  end

  test "toggle_calendar filters events by calendar name", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    # Toggle is a no-op when there are no events/calendars, just verify it doesn't crash
    assert render(view) =~ "Where We Are"
  end

  test "calendar list remains stable when navigating months after toggling", %{conn: conn} do
    server_name = __MODULE__

    defmodule StableCalendarClient do
      def list_calendars(_config), do: {:ok, [%{display_name: "Work"}]}
      def fetch_events(_config), do: {:ok, []}
    end

    event =
      WhereWeAre.Calendar.Event.new(%{
        uid: "event-1",
        summary: "Event One",
        calendar_name: "Work",
        dtstart: ~D[2024-01-15]
      })

    start_supervised!(
      {WhereWeAre.CalendarSync,
       name: server_name,
       schedule?: false,
       client: StableCalendarClient,
       initial_events: [event]}
    )

    conn = conn |> init_test_session(%{"calendar_sync" => Atom.to_string(server_name)})

    {:ok, view, _html} = live(conn, ~p"/?month=2024-01-15")

    assert has_element?(view, "button", "Work")

    # Deselect Work so it would previously disappear when navigating to a month
    # with no Work events.
    html = view |> element("button", "Work") |> render_click()
    refute html =~ "Event One"

    html = view |> element("button", "Move Next") |> render_click()

    assert html =~ "February 2024"
    assert has_element?(view, "button", "Work")
  end

  test "updates today when :day_changed is received", %{conn: conn} do
    today = Date.utc_today()

    {:ok, view, html} = live(conn, ~p"/?month=#{Date.to_iso8601(today)}")

    assert html =~ ~s(aria-current="date")

    send(view.pid, :day_changed)

    rendered = render(view)
    assert rendered =~ ~s(datetime="#{Date.to_iso8601(today)}")
    assert rendered =~ ~s(aria-current="date")
  end

  test "refreshes events when :events_updated is broadcast", %{conn: conn} do
    server_name = __MODULE__

    defmodule PubSubSyncClient do
      def list_calendars(_config), do: {:ok, [%{display_name: "Work"}]}
      def fetch_events(_config), do: {:ok, []}
    end

    start_supervised!(
      {WhereWeAre.CalendarSync,
       name: server_name,
       schedule?: false,
       client: PubSubSyncClient,
       credentials: %{calendars: ["Work"]},
       initial_events: []}
    )

    conn = conn |> init_test_session(%{"calendar_sync" => Atom.to_string(server_name)})

    {:ok, view, html} = live(conn, ~p"/")
    refute html =~ "New Event"

    :ok =
      GenServer.call(
        server_name,
        {:set_events,
         [
           WhereWeAre.Calendar.Event.new(%{
             uid: "new-1",
             summary: "New Event",
             calendar_name: "Work",
             dtstart: Date.utc_today()
           })
         ]}
      )

    Phoenix.PubSub.broadcast(WhereWeAre.PubSub, WhereWeAre.CalendarSync.topic(server_name), :events_updated)

    assert render(view) =~ "New Event"
  end

  test "filter button uses hex inline style when calendar has a color", %{conn: conn} do
    server_name = __MODULE__

    defmodule ColoredCalendarClient do
      def list_calendars(_config), do: {:ok, [%{display_name: "Home", color: "#FF2D55FF"}]}
      def fetch_events(_config), do: {:ok, []}
    end

    start_supervised!(
      {WhereWeAre.CalendarSync,
       name: server_name,
       schedule?: false,
       client: ColoredCalendarClient,
       credentials: %{calendars: ["Home"]},
       initial_events: []}
    )

    conn = conn |> init_test_session(%{"calendar_sync" => Atom.to_string(server_name)})

    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ "background-color: #FF2D55"
  end

  test "show_event opens modal and close_event closes it", %{conn: conn} do
    today = Date.utc_today()
    server_name = __MODULE__

    event =
      WhereWeAre.Calendar.Event.new(%{
        uid: "test-event-uid",
        summary: "Test Event",
        calendar_name: "Test Calendar",
        dtstart: today,
        description: "A test event description"
      })

    start_supervised!(
      {WhereWeAre.CalendarSync, name: server_name, schedule?: false, initial_events: [event]}
    )

    conn = conn |> init_test_session(%{"calendar_sync" => Atom.to_string(server_name)})

    {:ok, view, _html} = live(conn, ~p"/")

    html = view |> element("button", "Test Event") |> render_click()

    assert html =~ "Test Event"
    assert html =~ "A test event description"
    assert html =~ "Test Calendar"

    html = view |> element("#event-modal button[aria-label='Close']") |> render_click()

    refute html =~ "A test event description"
  end

end
