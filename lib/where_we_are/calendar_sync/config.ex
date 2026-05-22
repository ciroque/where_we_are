defmodule WhereWeAre.CalendarSync.Config do
  def from_env do
    [
      client: WhereWeAre.CalendarSync.CaldavClient,
      poll_interval: :timer.minutes(10),
      credentials: %{
        username: System.get_env("CALDAV_USERNAME"),
        password: System.get_env("CALDAV_PASSWORD"),
        url: System.get_env("CALDAV_URL")
      }
    ]
  end
end
