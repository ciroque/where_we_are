defmodule WhereWeAre.CalendarSync.CaldavClient do
  @base_url "https://caldav.icloud.com"

  def fetch_events(%{apple_id: nil}), do: {:error, :missing_icloud_apple_id}
  def fetch_events(%{app_password: nil}), do: {:error, :missing_icloud_app_password}
  def fetch_events(config) when not is_map_key(config, :apple_id), do: {:error, :missing_icloud_apple_id}
  def fetch_events(config) when not is_map_key(config, :app_password), do: {:error, :missing_icloud_app_password}

  def fetch_events(config) do
    config
    |> caldav_client()
    |> client(config).fetch_events(config)
  end

  defp client(%{client: client}), do: client
  defp client(_config), do: __MODULE__.LibraryClient

  defp caldav_client(config) do
    %CalDAVClient.Client{
      server_url: @base_url,
      auth: %CalDAVClient.Auth.Basic{
        username: config.apple_id,
        password: config.app_password
      }
    }
  end

  defmodule LibraryClient do
    def fetch_events(_caldav_client, _config), do: {:error, :not_implemented}
  end
end
