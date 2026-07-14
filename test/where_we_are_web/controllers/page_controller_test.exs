defmodule WhereWeAreWeb.PageControllerTest do
  use WhereWeAreWeb.ConnCase

  alias WhereWeAre.Calendar.Event
  alias WhereWeAreWeb.PageHTML

  describe "PageHTML.calendar_color/1 and /2" do
    test "returns bg_style and text_style for an 8-char CalDAV hex" do
      color = PageHTML.calendar_color("My Calendar", "#FF2D55FF")
      assert color.bg_style == "background-color: #FF2D55"
      assert color.text_style == "color: #ffffff"
      assert color.bg == nil
      assert color.text == nil
    end

    test "returns bg_style and text_style for a 6-char hex" do
      color = PageHTML.calendar_color("My Calendar", "#FF2D55")
      assert color.bg_style == "background-color: #FF2D55"
      assert color.text_style == "color: #ffffff"
    end

    test "picks dark text for a light hex color" do
      color = PageHTML.calendar_color("My Calendar", "#FFFFFF")
      assert color.text_style == "color: #111827"
    end

    test "falls back to Tailwind classes when hex is invalid" do
      color = PageHTML.calendar_color("My Calendar", "red; background: evil")
      assert is_binary(color.bg)
      refute Map.has_key?(color, :bg_style)
    end

    test "falls back to Tailwind classes when hex is nil" do
      color = PageHTML.calendar_color("My Calendar", nil)
      assert is_binary(color.bg)
      assert is_binary(color.text)
      refute Map.has_key?(color, :bg_style)
    end

    test "falls back to Tailwind classes when name is nil" do
      color = PageHTML.calendar_color(nil)
      assert is_binary(color.bg)
      assert is_binary(color.text)
    end
  end

  test "GET / shows current month calendar", %{conn: conn} do
    today = ~D[2024-01-15]

    conn =
      conn
      |> Plug.Conn.assign(:today, today)
      |> get(~p"/static")

    month_label = Calendar.strftime(today, "%B %Y")
    first_of_month = Date.beginning_of_month(today)
    prev_month = first_of_month |> Date.add(-1) |> Date.beginning_of_month()

    next_month =
      first_of_month
      |> Date.add(Date.days_in_month(first_of_month))
      |> Date.beginning_of_month()

    response = html_response(conn, 200)

    assert response =~ month_label
    assert response =~ "Move Previous"
    assert response =~ "Move Next"
    assert response =~ "Today"
    assert response =~ ~s(href="/static?month=#{Date.to_iso8601(prev_month)}")
    assert response =~ ~s(href="/static?month=#{Date.to_iso8601(next_month)}")
    assert response =~ ~s(href="/static?today=true")

    assert response =~ "Sun"
    assert response =~ "Mon"
    assert response =~ "Tue"
    assert response =~ "Wed"
    assert response =~ "Thu"
    assert response =~ "Fri"
    assert response =~ "Sat"
  end

  test "GET / renders events for the displayed month", %{conn: conn} do
    today = ~D[2024-01-15]

    events = [
      Event.new(%{
        uid: "dinner",
        dtstart: DateTime.new!(~D[2024-01-20], ~T[18:00:00], "Etc/UTC"),
        summary: "Family Dinner"
      }),
      Event.new(%{
        uid: "lunch",
        dtstart: DateTime.new!(~D[2024-01-10], ~T[12:00:00], "Etc/UTC"),
        summary: "Team Lunch"
      })
    ]

    conn =
      conn
      |> Plug.Conn.assign(:today, today)
      |> Plug.Conn.assign(:events, events)
      |> get(~p"/static")

    response = html_response(conn, 200)

    assert response =~ "Family Dinner"
    assert response =~ "Team Lunch"

    # Event slugs appear in calendar day cells
    assert response =~ "bg-emerald-100"

    # Past / Upcoming delimiter
    assert response =~ "Past"
    assert response =~ "Today &amp; Upcoming"

    # Past events are muted, upcoming are not
    assert response =~ "opacity-60"
  end

  test "GET / converts event times to local timezone", %{conn: conn} do
    today = ~D[2024-01-15]

    events = [
      Event.new(%{
        uid: "late-utc",
        dtstart: DateTime.new!(~D[2024-01-16], ~T[02:00:00], "Etc/UTC"),
        summary: "Late Night Event"
      })
    ]

    conn =
      conn
      |> Plug.Conn.assign(:today, today)
      |> Plug.Conn.assign(:events, events)
      |> Plug.Conn.assign(:timezone, "America/Denver")
      |> get(~p"/static")

    response = html_response(conn, 200)

    # 2024-01-16 02:00 UTC = 2024-01-15 19:00 MST (America/Denver is UTC-7 in Jan)
    assert response =~ "7:00 PM"
  end

  test "GET / with month param shows requested month", %{conn: conn} do
    today = ~D[2024-01-15]
    displayed_month = ~D[2024-03-01]

    conn =
      conn
      |> Plug.Conn.assign(:today, today)
      |> get(~p"/static?month=#{Date.to_iso8601(displayed_month)}")

    month_label = Calendar.strftime(displayed_month, "%B %Y")
    prev_month = displayed_month |> Date.add(-1) |> Date.beginning_of_month()

    next_month =
      displayed_month
      |> Date.add(Date.days_in_month(displayed_month))
      |> Date.beginning_of_month()

    response = html_response(conn, 200)

    assert response =~ month_label
    assert response =~ "Today"
    assert response =~ ~s(href="/static?month=#{Date.to_iso8601(prev_month)}")
    assert response =~ ~s(href="/static?month=#{Date.to_iso8601(next_month)}")
    assert response =~ ~s(href="/static?today=true")
  end
end
