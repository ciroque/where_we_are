defmodule WhereWeAre.CalendarSync.ConfigReloadTest do
  use ExUnit.Case, async: false

  alias WhereWeAre.CalendarSync

  defmodule CaptureClient do
    @behaviour WhereWeAre.Calendar.Client

    @impl true
    def fetch_events(config) do
      case config do
        %{captures: agent} -> Agent.update(agent, fn list -> [config | list] end)
        _ -> :ok
      end

      {:ok, []}
    end

    @impl true
    def list_calendars(_config), do: {:ok, []}
  end

  setup do
    original_dir = System.get_env("CALDAV_CONFIG_DIR")
    on_exit(fn -> restore_env("CALDAV_CONFIG_DIR", original_dir) end)
    :ok
  end

  test "sync_now reloads filter and window from config dir without restart" do
    dir =
      System.tmp_dir!()
      |> Path.join("wwa-reload-#{System.unique_integer([:positive])}")

    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)

    File.write!(Path.join(dir, "CALDAV_CALENDARS"), "Home")
    File.write!(Path.join(dir, "CALDAV_EVENT_WINDOW_MONTHS"), "6")
    System.put_env("CALDAV_CONFIG_DIR", dir)

    captures = start_supervised!({Agent, fn -> [] end})

    {:ok, pid} =
      start_supervised(
        {CalendarSync,
         name: :calendar_sync_reload_test,
         client: CaptureClient,
         credentials: %{
           username: "u",
           password: "p",
           captures: captures
         },
         filter: %{calendars: ["Home"]},
         event_window_months: 6,
         schedule?: false}
      )

    assert {:ok, []} = CalendarSync.sync_now(pid)
    assert %{configured_calendars: ["Home"], event_window_months: 6} = CalendarSync.state(pid)

    File.write!(Path.join(dir, "CALDAV_CALENDARS"), "Work, School")
    File.write!(Path.join(dir, "CALDAV_EVENT_WINDOW_MONTHS"), "2")

    assert {:ok, []} = CalendarSync.sync_now(pid)

    assert %{
             configured_calendars: ["Work", "School"],
             event_window_months: 2
           } = CalendarSync.state(pid)

    [latest | _] = Agent.get(captures, & &1)
    assert latest.calendars == ["Work", "School"]
    assert latest.event_window_months == 2
  end

  defp restore_env(key, nil), do: System.delete_env(key)
  defp restore_env(key, value), do: System.put_env(key, value)
end
