defmodule WhereWeAre.CalendarSync.ConfigTest do
  use ExUnit.Case, async: false

  alias WhereWeAre.CalendarSync.Config

  setup do
    original_username = System.get_env("CALDAV_USERNAME")
    original_password = System.get_env("CALDAV_PASSWORD")
    original_url = System.get_env("CALDAV_URL")
    original_calendars = System.get_env("CALDAV_CALENDARS")
    original_window = System.get_env("CALDAV_EVENT_WINDOW_MONTHS")

    on_exit(fn ->
      restore_env("CALDAV_USERNAME", original_username)
      restore_env("CALDAV_PASSWORD", original_password)
      restore_env("CALDAV_URL", original_url)
      restore_env("CALDAV_CALENDARS", original_calendars)
      restore_env("CALDAV_EVENT_WINDOW_MONTHS", original_window)
    end)

    :ok
  end

  test "builds CalendarSync config from CalDAV environment variables" do
    clear_optional_env()
    System.put_env("CALDAV_USERNAME", "person@example.com")
    System.put_env("CALDAV_PASSWORD", "app-specific-password")

    assert Config.from_env() == [
             client: WhereWeAre.CalendarSync.CaldavClient,
             poll_interval: :timer.minutes(10),
             event_window_months: 6,
             credentials: %{
               username: "person@example.com",
               password: "app-specific-password"
             }
           ]
  end

  test "treats whitespace CalDAV URL as absent" do
    clear_optional_env()
    System.put_env("CALDAV_USERNAME", "person@example.com")
    System.put_env("CALDAV_PASSWORD", "app-specific-password")
    System.put_env("CALDAV_URL", "   ")

    assert Config.from_env() == [
             client: WhereWeAre.CalendarSync.CaldavClient,
             poll_interval: :timer.minutes(10),
             event_window_months: 6,
             credentials: %{
               username: "person@example.com",
               password: "app-specific-password"
             }
           ]
  end

  test "omits calendars key when CALDAV_CALENDARS is blank" do
    clear_optional_env()
    System.put_env("CALDAV_USERNAME", "person@example.com")
    System.put_env("CALDAV_PASSWORD", "app-specific-password")
    System.put_env("CALDAV_CALENDARS", "   , ,  ")

    assert Config.from_env() == [
             client: WhereWeAre.CalendarSync.CaldavClient,
             poll_interval: :timer.minutes(10),
             event_window_months: 6,
             credentials: %{
               username: "person@example.com",
               password: "app-specific-password"
             }
           ]
  end

  test "includes custom CalDAV URL when provided" do
    clear_optional_env()
    System.put_env("CALDAV_USERNAME", "person@example.com")
    System.put_env("CALDAV_PASSWORD", "app-specific-password")
    System.put_env("CALDAV_URL", "https://example.com/caldav")

    assert Config.from_env() == [
             client: WhereWeAre.CalendarSync.CaldavClient,
             poll_interval: :timer.minutes(10),
             event_window_months: 6,
             credentials: %{
               username: "person@example.com",
               password: "app-specific-password",
               url: "https://example.com/caldav"
             }
           ]
  end

  defp restore_env(key, nil), do: System.delete_env(key)
  defp restore_env(key, value), do: System.put_env(key, value)

  defp clear_optional_env do
    System.delete_env("CALDAV_URL")
    System.delete_env("CALDAV_CALENDARS")
    System.delete_env("CALDAV_EVENT_WINDOW_MONTHS")
  end
end
