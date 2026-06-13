defmodule WhereWeAreWeb.Router do
  use WhereWeAreWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_cookies
    plug :fetch_live_flash
    plug :put_root_layout, html: {WhereWeAreWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", WhereWeAreWeb do
    pipe_through :browser

    get "/static", PageController, :home

    live_session :default, session: {WhereWeAreWeb.CalendarLive, :session, []} do
      live "/", CalendarLive
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", WhereWeAreWeb do
  #   pipe_through :api
  # end
end
