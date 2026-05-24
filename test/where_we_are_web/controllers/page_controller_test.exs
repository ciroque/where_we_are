defmodule WhereWeAreWeb.PageControllerTest do
  use WhereWeAreWeb.ConnCase

  test "GET / shows current month calendar", %{conn: conn} do
    today = ~D[2024-01-15]

    conn =
      conn
      |> Plug.Conn.assign(:today, today)
      |> get(~p"/")

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
    assert response =~ ~s(href="/?month=#{Date.to_iso8601(prev_month)}")
    assert response =~ ~s(href="/?month=#{Date.to_iso8601(next_month)}")
    assert response =~ ~s(href="/?today=true")

    assert response =~ "Sun"
    assert response =~ "Mon"
    assert response =~ "Tue"
    assert response =~ "Wed"
    assert response =~ "Thu"
    assert response =~ "Fri"
    assert response =~ "Sat"
  end

  test "GET / with month param shows requested month", %{conn: conn} do
    today = ~D[2024-01-15]
    displayed_month = ~D[2024-03-01]

    conn =
      conn
      |> Plug.Conn.assign(:today, today)
      |> get(~p"/?month=#{Date.to_iso8601(displayed_month)}")

    month_label = Calendar.strftime(displayed_month, "%B %Y")
    prev_month = displayed_month |> Date.add(-1) |> Date.beginning_of_month()

    next_month =
      displayed_month
      |> Date.add(Date.days_in_month(displayed_month))
      |> Date.beginning_of_month()

    response = html_response(conn, 200)

    assert response =~ month_label
    assert response =~ "Today"
    assert response =~ ~s(href="/?month=#{Date.to_iso8601(prev_month)}")
    assert response =~ ~s(href="/?month=#{Date.to_iso8601(next_month)}")
    assert response =~ ~s(href="/?today=true")
  end
end
