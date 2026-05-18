defmodule WhereWeAre.CalendarSync.Config do
  def from_env do
    [
      client: WhereWeAre.CalendarSync.CaldavClient,
      poll_interval: :timer.minutes(10),
      credentials: %{
        apple_id: System.get_env("ICLOUD_APPLE_ID"),
        app_password: System.get_env("ICLOUD_APP_PASSWORD")
      }
    ]
  end
end
