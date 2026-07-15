defmodule WhereWeAre.CalendarSync.Config do
  @moduledoc """
  Builds CalendarSync options from environment variables.

  Internal option shape separates auth, server, filter, and sync settings while
  keeping the public env var names stable.
  """
  def from_env do
    [
      client: WhereWeAre.CalendarSync.CaldavClient,
      poll_interval: poll_interval_from_env(),
      event_window_months: parse_integer(System.get_env("CALDAV_EVENT_WINDOW_MONTHS"), 6),
      expand_recurrences: parse_boolean(System.get_env("CALDAV_EXPAND_RECURRENCES"), true),
      auth: %{
        username: System.get_env("CALDAV_USERNAME"),
        password: System.get_env("CALDAV_PASSWORD")
      },
      server: server_from_env(),
      filter: filter_from_env()
    ]
  end

  defp poll_interval_from_env do
    minutes = parse_integer(System.get_env("CALDAV_POLL_MINUTES"), 10)
    :timer.minutes(max(minutes, 1))
  end

  defp server_from_env do
    case normalize_presence(System.get_env("CALDAV_URL")) do
      nil -> %{}
      url -> %{url: url}
    end
  end

  defp filter_from_env do
    case parse_calendars(System.get_env("CALDAV_CALENDARS")) do
      nil -> %{}
      calendars -> %{calendars: calendars}
    end
  end

  defp parse_calendars(nil), do: nil
  defp parse_calendars(""), do: nil

  defp parse_calendars(calendars_string) do
    calendars_string
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> presence()
  end

  defp parse_integer(nil, default), do: default
  defp parse_integer("", default), do: default

  defp parse_integer(value, default) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> default
    end
  end

  defp parse_boolean(nil, default), do: default
  defp parse_boolean("", default), do: default
  defp parse_boolean(value, _default) when value in ["true", "1"], do: true
  defp parse_boolean(value, _default) when value in ["false", "0"], do: false
  defp parse_boolean(_value, default), do: default

  defp normalize_presence(nil), do: nil

  defp normalize_presence(value) when is_binary(value) do
    value
    |> String.trim()
    |> case do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp presence([]), do: nil
  defp presence(value), do: value
end
