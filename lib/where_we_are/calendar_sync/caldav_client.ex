defmodule WhereWeAre.CalendarSync.CaldavClient do
  @base_url "https://caldav.icloud.com"

  def authenticate(config) do
    with :ok <- validate_config(config),
         {:ok, _discovery_info} <- client(config).discover(caldav_client(config)) do
      :ok
    end
  end

  def list_calendars(%{username: nil}), do: {:error, :missing_caldav_username}
  def list_calendars(%{password: nil}), do: {:error, :missing_caldav_password}

  def list_calendars(config) when not is_map_key(config, :username),
    do: {:error, :missing_caldav_username}

  def list_calendars(config) when not is_map_key(config, :password),
    do: {:error, :missing_caldav_password}

  def list_calendars(config) do
    caldav_client = caldav_client(config)
    client = client(config)

    with {:ok, discovery_info} <- client.discover(caldav_client),
         {:ok, calendars} <- client.list_calendars(caldav_client, discovery_info) do
      {:ok, calendars}
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
    time_range_opts = build_time_range_opts(config)

    with {:ok, discovery_info} <- client.discover(caldav_client),
         {:ok, calendars} <- client.list_calendars(caldav_client, discovery_info) do
      calendars
      |> filter_calendars(config)
      |> Enum.reduce_while({:ok, []}, fn calendar, {:ok, events} ->
        case client.list_events(caldav_client, calendar.url, time_range_opts) do
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

  defp filter_calendars(calendars, %{calendars: calendar_names})
       when is_list(calendar_names) and calendar_names != [] do
    Enum.filter(calendars, fn calendar -> calendar.display_name in calendar_names end)
  end

  defp filter_calendars(calendars, _config), do: calendars

  defp build_time_range_opts(%{event_window_months: 0}) do
    today = Date.utc_today()
    window_open = today |> Date.beginning_of_month() |> to_datetime()
    window_close = today |> Date.end_of_month() |> to_datetime(:end_of_day)
    [from: window_open, to: window_close]
  end

  defp build_time_range_opts(%{event_window_months: months}) when is_integer(months) do
    today = Date.utc_today()
    window_open = today |> Date.shift(month: -months) |> Date.beginning_of_month() |> to_datetime()
    window_close = today |> Date.shift(month: months) |> Date.end_of_month() |> to_datetime(:end_of_day)
    [from: window_open, to: window_close]
  end

  defp build_time_range_opts(_config), do: []

  defp to_datetime(date, :end_of_day) do
    DateTime.new!(date, ~T[23:59:59], "Etc/UTC")
  end

  defp to_datetime(date) do
    DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
  end
end
