defmodule WhereWeAreWeb.PageControllerTest do
  use WhereWeAreWeb.ConnCase, async: true

  test "GET /static redirects to LiveView calendar", %{conn: conn} do
    conn = get(conn, "/static")
    assert redirected_to(conn) == "/"
  end
end
