defmodule WhereWeAre.CalendarSync.Config do
  @moduledoc """
  Builds a keyword list of CalendarSync options from environment variables.
  """
  def from_env do
    url = System.get_env("CALDAV_URL")
    calendars = parse_calendars(System.get_env("CALDAV_CALENDARS"))

    credentials =
      %{
        username: System.get_env("CALDAV_USERNAME"),
        password: System.get_env("CALDAV_PASSWORD")
      }
      |> maybe_put(:url, normalize_presence(url))
      |> maybe_put(:calendars, calendars)

    [
      client: WhereWeAre.CalendarSync.CaldavClient,
      poll_interval: :timer.minutes(10),
      event_window_months: parse_integer(System.get_env("CALDAV_EVENT_WINDOW_MONTHS"), 6),
      credentials: credentials
    ]
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

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

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
