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
end
