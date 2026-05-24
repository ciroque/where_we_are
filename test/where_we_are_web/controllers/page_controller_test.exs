defmodule WhereWeAreWeb.PageControllerTest do
  use WhereWeAreWeb.ConnCase

  test "GET / shows current month calendar", %{conn: conn} do
    today = ~D[2024-01-15]

    conn =
      conn
      |> Plug.Conn.assign(:today, today)
      |> get(~p"/")

    month_label = Calendar.strftime(today, "%B %Y")

    response = html_response(conn, 200)

    assert response =~ month_label

    assert response =~ "Sun"
    assert response =~ "Mon"
    assert response =~ "Tue"
    assert response =~ "Wed"
    assert response =~ "Thu"
    assert response =~ "Fri"
    assert response =~ "Sat"
  end
end
