defmodule WhereWeAre.CalendarSync.ConfigTest do
  use ExUnit.Case, async: false

  alias WhereWeAre.CalendarSync.Config

  setup do
    original_username = System.get_env("CALDAV_USERNAME")
    original_password = System.get_env("CALDAV_PASSWORD")

    on_exit(fn ->
      restore_env("CALDAV_USERNAME", original_username)
      restore_env("CALDAV_PASSWORD", original_password)
    end)

    :ok
  end

  test "builds CalendarSync config from CalDAV environment variables" do
    System.put_env("CALDAV_USERNAME", "person@example.com")
    System.put_env("CALDAV_PASSWORD", "app-specific-password")

    assert Config.from_env() == [
             client: WhereWeAre.CalendarSync.CaldavClient,
             poll_interval: :timer.minutes(10),
             credentials: %{
               username: "person@example.com",
               password: "app-specific-password"
             }
           ]
  end

  defp restore_env(key, nil), do: System.delete_env(key)
  defp restore_env(key, value), do: System.put_env(key, value)
end
