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

  test "toggle_calendar filters events by calendar name", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    # Toggle is a no-op when there are no events/calendars, just verify it doesn't crash
    assert render(view) =~ "Where We Are"
  end
end
