defmodule WhereWeAre.CalendarSyncTest do
  use ExUnit.Case, async: true

  alias WhereWeAre.CalendarSync

  defmodule SuccessfulClient do
    def fetch_events(_config) do
      {:ok, [%{id: "family-dinner", title: "Family Dinner"}]}
    end
  end

  defmodule FailingClient do
    def fetch_events(_config), do: {:error, :icloud_unavailable}
  end

  test "starts with configured client, poll interval, and credentials" do
    {:ok, pid} =
      start_supervised(
        {CalendarSync,
         name: :calendar_sync_config_test,
         client: SuccessfulClient,
         poll_interval: :timer.minutes(10),
         credentials: %{username: "person@example.com", password: "app-specific-password"},
         schedule?: false}
      )

    assert CalendarSync.state(pid) == %{
             client: SuccessfulClient,
             poll_interval: :timer.minutes(10),
             event_window_months: 6,
             credentials: %{username: "person@example.com", password: "app-specific-password"},
             last_sync: nil,
             last_error: nil,
             events: []
           }
  end

  test "sync_now fetches events with the configured client and stores them in memory" do
    {:ok, pid} =
      start_supervised(
        {CalendarSync,
         name: :calendar_sync_success_test,
         client: SuccessfulClient,
         poll_interval: :timer.minutes(10),
         credentials: %{username: "person@example.com", password: "app-specific-password"},
         schedule?: false}
      )

    assert {:ok, [%{title: "Family Dinner"}]} = CalendarSync.sync_now(pid)

    assert %{
             events: [%{title: "Family Dinner"}],
             last_sync: %DateTime{},
             last_error: nil
           } = CalendarSync.state(pid)
  end

  test "sync_now keeps current events and records the error when fetch fails" do
    {:ok, pid} =
      start_supervised(
        {CalendarSync,
         name: :calendar_sync_failure_test,
         client: FailingClient,
         poll_interval: :timer.minutes(10),
         credentials: %{username: "person@example.com", password: "app-specific-password"},
         initial_events: [%{id: "existing", title: "Existing Event"}],
         schedule?: false}
      )

    assert {:error, :icloud_unavailable} = CalendarSync.sync_now(pid)

    assert %{
             events: [%{title: "Existing Event"}],
             last_error: :icloud_unavailable,
             last_sync: nil
           } = CalendarSync.state(pid)
  end

  describe "events_for_month/2" do
    test "returns events starting within the month when dtstart is a DateTime" do
      {:ok, pid} =
        start_supervised(
          {CalendarSync,
           name: :calendar_sync_events_month_test,
           schedule?: false,
           initial_events: [
             %{
               id: "jan-early",
               dtstart: DateTime.new!(~D[2024-01-05], ~T[09:00:00], "Etc/UTC")
             },
             %{
               id: "feb-start",
               dtstart: DateTime.new!(~D[2024-02-01], ~T[08:00:00], "Etc/UTC")
             },
             %{id: "jan-late", dtstart: DateTime.new!(~D[2024-01-31], ~T[18:30:00], "Etc/UTC")}
           ]}
        )

      january = ~D[2024-01-01]

      assert [%{id: "jan-early"}, %{id: "jan-late"}] =
               CalendarSync.events_for_month(pid, january)
    end

    test "filters by both month and year" do
      {:ok, pid} =
        start_supervised(
          {CalendarSync,
           name: :calendar_sync_events_year_test,
           schedule?: false,
           initial_events: [
             %{
               id: "may-2025",
               dtstart: DateTime.new!(~D[2025-05-10], ~T[10:00:00], "Etc/UTC")
             },
             %{
               id: "may-2026",
               dtstart: DateTime.new!(~D[2026-05-10], ~T[10:00:00], "Etc/UTC")
             },
             %{
               id: "june-2026",
               dtstart: DateTime.new!(~D[2026-06-01], ~T[08:00:00], "Etc/UTC")
             }
           ]}
        )

      assert [%{id: "may-2026"}] = CalendarSync.events_for_month(pid, ~D[2026-05-01])
      assert [%{id: "may-2025"}] = CalendarSync.events_for_month(pid, ~D[2025-05-01])
    end

    test "supports events with Date dtstart and ignores events missing dtstart" do
      {:ok, pid} =
        start_supervised(
          {CalendarSync,
           name: :calendar_sync_events_month_date_test,
           schedule?: false,
           initial_events: [
             %{id: "with-date", dtstart: ~D[2024-01-10]},
             %{id: "missing-date"}
           ]}
        )

      january = ~D[2024-01-01]

      assert [%{id: "with-date"}] = CalendarSync.events_for_month(pid, january)
      assert [] = CalendarSync.events_for_month(pid, ~D[2024-02-01])
    end
  end
end
