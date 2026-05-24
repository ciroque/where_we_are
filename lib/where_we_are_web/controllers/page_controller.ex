defmodule WhereWeAreWeb.PageController do
  use WhereWeAreWeb, :controller

  def home(conn, _params) do
    today = conn.assigns[:today] || Date.utc_today()

    render(conn, :home, layout: false, today: today)
  end
end
