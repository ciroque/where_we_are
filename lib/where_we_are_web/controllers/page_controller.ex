defmodule WhereWeAreWeb.PageController do
  use WhereWeAreWeb, :controller

  def home(conn, _params) do
    redirect(conn, to: ~p"/")
  end
end
