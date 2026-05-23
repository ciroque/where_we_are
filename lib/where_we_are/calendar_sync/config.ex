defmodule WhereWeAre.CalendarSync.Config do
  def from_env do
    [
      client: WhereWeAre.CalendarSync.CaldavClient,
      poll_interval: :timer.minutes(10),
      event_window_months: parse_integer(System.get_env("CALDAV_EVENT_WINDOW_MONTHS"), 6),
      credentials: %{
        username: System.get_env("CALDAV_USERNAME"),
        password: System.get_env("CALDAV_PASSWORD"),
        url: System.get_env("CALDAV_URL"),
        calendars: parse_calendars(System.get_env("CALDAV_CALENDARS"))
      }
    ]
  end

  defp parse_calendars(nil), do: nil
  defp parse_calendars(""), do: nil

  defp parse_calendars(calendars_string) do
    calendars_string
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp parse_integer(nil, default), do: default
  defp parse_integer("", default), do: default

  defp parse_integer(value, default) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> default
    end
  end
end
