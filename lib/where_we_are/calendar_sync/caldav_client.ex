defmodule WhereWeAre.CalendarSync.CaldavClient do
  @base_url "https://caldav.icloud.com"

  def authenticate(config) do
    with :ok <- validate_config(config),
         {:ok, _discovery_info} <- client(config).discover(caldav_client(config)) do
      :ok
    end
  end

  def fetch_events(%{username: nil}), do: {:error, :missing_caldav_username}
  def fetch_events(%{password: nil}), do: {:error, :missing_caldav_password}

  def fetch_events(config) when not is_map_key(config, :username),
    do: {:error, :missing_caldav_username}

  def fetch_events(config) when not is_map_key(config, :password),
    do: {:error, :missing_caldav_password}

  def fetch_events(config) do
    caldav_client = caldav_client(config)
    client = client(config)

    with {:ok, discovery_info} <- client.discover(caldav_client),
         {:ok, calendars} <- client.list_calendars(caldav_client, discovery_info) do
      calendars
      |> Enum.reduce_while({:ok, []}, fn calendar, {:ok, events} ->
        case client.list_events(caldav_client, calendar.url) do
          {:ok, calendar_events} -> {:cont, {:ok, events ++ calendar_events}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
    end
  end

  defp client(%{client: client}), do: client
  defp client(_config), do: CalDAVEx

  defp caldav_client(config) do
    base_url = Map.get(config, :url, @base_url)

    base_url
    |> CalDAVEx.new_config(CalDAVEx.basic_auth(config.username, config.password))
    |> CalDAVEx.new_client()
  end

  defp validate_config(%{username: nil}), do: {:error, :missing_caldav_username}
  defp validate_config(%{password: nil}), do: {:error, :missing_caldav_password}

  defp validate_config(config) when not is_map_key(config, :username),
    do: {:error, :missing_caldav_username}

  defp validate_config(config) when not is_map_key(config, :password),
    do: {:error, :missing_caldav_password}

  defp validate_config(_config), do: :ok
end
