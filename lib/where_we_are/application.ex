defmodule WhereWeAre.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      WhereWeAreWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:where_we_are, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: WhereWeAre.PubSub},
      {WhereWeAre.CalendarSync, Application.get_env(:where_we_are, WhereWeAre.CalendarSync, [])},
      # Start to serve requests, typically the last entry
      WhereWeAreWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: WhereWeAre.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    WhereWeAreWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
