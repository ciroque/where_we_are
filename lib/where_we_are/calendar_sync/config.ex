defmodule WhereWeAre.CalendarSync.Config do
  def from_env do
    [
      client: WhereWeAre.CalendarSync.CaldavClient,
      poll_interval: :timer.minutes(10),
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
end
