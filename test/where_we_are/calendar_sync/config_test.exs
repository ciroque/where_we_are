defmodule WhereWeAre.CalendarSync.ConfigTest do
  use ExUnit.Case, async: false

  alias WhereWeAre.CalendarSync.Config

  setup do
    keys = [
      "CALDAV_USERNAME",
      "CALDAV_PASSWORD",
      "CALDAV_URL",
      "CALDAV_CALENDARS",
      "CALDAV_EVENT_WINDOW_MONTHS",
      "CALDAV_EXPAND_RECURRENCES",
      "CALDAV_POLL_MINUTES"
    ]

    original = Map.new(keys, fn key -> {key, System.get_env(key)} end)

    on_exit(fn ->
      Enum.each(original, fn {key, value} -> restore_env(key, value) end)
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
             expand_recurrences: true,
             auth: %{
               username: "person@example.com",
               password: "app-specific-password"
             },
             server: %{},
             filter: %{}
           ]
  end

  test "treats whitespace CalDAV URL as absent" do
    clear_optional_env()
    System.put_env("CALDAV_USERNAME", "person@example.com")
    System.put_env("CALDAV_PASSWORD", "app-specific-password")
    System.put_env("CALDAV_URL", "   ")

    config = Config.from_env()
    assert config[:server] == %{}
  end

  test "omits calendars key when CALDAV_CALENDARS is blank" do
    clear_optional_env()
    System.put_env("CALDAV_USERNAME", "person@example.com")
    System.put_env("CALDAV_PASSWORD", "app-specific-password")
    System.put_env("CALDAV_CALENDARS", "   , ,  ")

    config = Config.from_env()
    assert config[:filter] == %{}
  end

  test "includes custom CalDAV URL and calendar filter when provided" do
    clear_optional_env()
    System.put_env("CALDAV_USERNAME", "person@example.com")
    System.put_env("CALDAV_PASSWORD", "app-specific-password")
    System.put_env("CALDAV_URL", "https://example.com/caldav")
    System.put_env("CALDAV_CALENDARS", "Home, Work")

    config = Config.from_env()
    assert config[:server] == %{url: "https://example.com/caldav"}
    assert config[:filter] == %{calendars: ["Home", "Work"]}
  end

  test "reads poll interval minutes from env" do
    clear_optional_env()
    System.put_env("CALDAV_USERNAME", "person@example.com")
    System.put_env("CALDAV_PASSWORD", "app-specific-password")
    System.put_env("CALDAV_POLL_MINUTES", "3")

    assert Config.from_env()[:poll_interval] == :timer.minutes(3)
  end

  defp restore_env(key, nil), do: System.delete_env(key)
  defp restore_env(key, value), do: System.put_env(key, value)

  defp clear_optional_env do
    System.delete_env("CALDAV_URL")
    System.delete_env("CALDAV_CALENDARS")
    System.delete_env("CALDAV_EVENT_WINDOW_MONTHS")
    System.delete_env("CALDAV_EXPAND_RECURRENCES")
    System.delete_env("CALDAV_POLL_MINUTES")
  end
end
