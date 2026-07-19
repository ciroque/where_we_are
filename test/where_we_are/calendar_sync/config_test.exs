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
      "CALDAV_POLL_MINUTES",
      "CALDAV_CONFIG_DIR"
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

  test "parses integer knobs with leading/trailing whitespace" do
    clear_optional_env()
    dir = System.tmp_dir!() |> Path.join("wwa-caldav-config-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)

    File.write!(Path.join(dir, "CALDAV_POLL_MINUTES"), "  3  \n")
    File.write!(Path.join(dir, "CALDAV_EVENT_WINDOW_MONTHS"), "\t12\n")
    System.put_env("CALDAV_USERNAME", "person@example.com")
    System.put_env("CALDAV_PASSWORD", "app-specific-password")
    System.put_env("CALDAV_CONFIG_DIR", dir)

    config = Config.from_env()
    assert config[:poll_interval] == :timer.minutes(3)
    assert config[:event_window_months] == 12
  end

  test "prefers config-dir files over env for filter knobs" do
    clear_optional_env()
    dir = System.tmp_dir!() |> Path.join("wwa-caldav-config-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)

    File.write!(Path.join(dir, "CALDAV_CALENDARS"), "Family, School\n")
    File.write!(Path.join(dir, "CALDAV_EVENT_WINDOW_MONTHS"), "3\n")

    System.put_env("CALDAV_USERNAME", "person@example.com")
    System.put_env("CALDAV_PASSWORD", "app-specific-password")
    System.put_env("CALDAV_CALENDARS", "FromEnv")
    System.put_env("CALDAV_EVENT_WINDOW_MONTHS", "12")
    System.put_env("CALDAV_CONFIG_DIR", dir)

    assert Config.config_dir_configured?()
    assert Config.from_env()[:filter] == %{calendars: ["Family", "School"]}
    assert Config.from_env()[:event_window_months] == 3
    assert Config.runtime_sync_opts() == [
             event_window_months: 3,
             filter: %{calendars: ["Family", "School"]}
           ]
  end

  test "falls back to env when config-dir file is missing" do
    clear_optional_env()
    dir = System.tmp_dir!() |> Path.join("wwa-caldav-config-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)

    System.put_env("CALDAV_USERNAME", "person@example.com")
    System.put_env("CALDAV_PASSWORD", "app-specific-password")
    System.put_env("CALDAV_CALENDARS", "Home")
    System.put_env("CALDAV_CONFIG_DIR", dir)

    assert Config.from_env()[:filter] == %{calendars: ["Home"]}
  end

  test "preserves leading/trailing spaces in config-dir values (only strips one line ending)" do
    clear_optional_env()
    dir = System.tmp_dir!() |> Path.join("wwa-caldav-config-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)

    File.write!(Path.join(dir, "CALDAV_PASSWORD"), " secret \n")
    File.write!(Path.join(dir, "CALDAV_USERNAME"), "user\n\n")
    System.put_env("CALDAV_CONFIG_DIR", dir)

    assert Config.from_env()[:auth].password == " secret "
    # Only one trailing newline removed
    assert Config.from_env()[:auth].username == "user\n"
  end

  test "logs once and falls back to env when config-dir file is unreadable" do
    clear_optional_env()
    dir = System.tmp_dir!() |> Path.join("wwa-caldav-config-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    path = Path.join(dir, "CALDAV_CALENDARS")
    # Force a deterministic read error (not :enoent) — File.read/1 fails with :eisdir.
    File.mkdir_p!(path)

    on_exit(fn ->
      File.rm_rf(dir)
      # Drop warn-once flag so later tests aren't affected.
      :persistent_term.erase({WhereWeAre.CalendarSync.Config, :config_read_failed, path})
    end)

    System.put_env("CALDAV_USERNAME", "person@example.com")
    System.put_env("CALDAV_PASSWORD", "app-specific-password")
    System.put_env("CALDAV_CALENDARS", "FromEnv")
    System.put_env("CALDAV_CONFIG_DIR", dir)

    first =
      ExUnit.CaptureLog.capture_log(fn ->
        assert Config.from_env()[:filter] == %{calendars: ["FromEnv"]}
      end)

    assert first =~ "CALDAV config read failed"

    second =
      ExUnit.CaptureLog.capture_log(fn ->
        assert Config.runtime_sync_opts()[:filter] == %{calendars: ["FromEnv"]}
      end)

    refute second =~ "CALDAV config read failed"
  end

  defp restore_env(key, nil), do: System.delete_env(key)
  defp restore_env(key, value), do: System.put_env(key, value)

  defp clear_optional_env do
    System.delete_env("CALDAV_URL")
    System.delete_env("CALDAV_CALENDARS")
    System.delete_env("CALDAV_EVENT_WINDOW_MONTHS")
    System.delete_env("CALDAV_EXPAND_RECURRENCES")
    System.delete_env("CALDAV_POLL_MINUTES")
    System.delete_env("CALDAV_CONFIG_DIR")
  end
end
