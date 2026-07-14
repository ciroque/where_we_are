defmodule WhereWeAre.CalendarSync.StoreTest do
  use ExUnit.Case, async: true

  alias WhereWeAre.Calendar.Event
  alias WhereWeAre.CalendarSync.Store

  test "events_for_month filters without starting a GenServer" do
    store =
      Store.new(
        client: WhereWeAre.Calendar.NoopClient,
        initial_events: [
          Event.new(%{uid: "a", summary: "A", dtstart: ~D[2024-01-10]}),
          Event.new(%{uid: "b", summary: "B", dtstart: ~D[2024-02-10]})
        ]
      )

    assert [%Event{uid: "a"}] = Store.events_for_month(store, ~D[2024-01-01])
  end

  test "public_status redacts password credentials" do
    store =
      Store.new(
        client: WhereWeAre.Calendar.NoopClient,
        credentials: %{username: "u", password: "secret", calendars: ["Home"]}
      )

    status = Store.public_status(store)

    assert status.credentials.password == :redacted
    assert status.credentials.username == "u"
    assert status.configured_calendars == ["Home"]
  end

  test "put_events records sync time and clears errors" do
    store =
      Store.new(client: WhereWeAre.Calendar.NoopClient)
      |> Store.put_error(:boom)

    events = [Event.new(%{uid: "1", summary: "One", dtstart: ~D[2024-01-01]})]
    store = Store.put_events(store, events, calendars: [%{display_name: "Home"}])

    assert store.last_error == nil
    assert %DateTime{} = store.last_sync
    assert store.events == events
    assert store.calendars == [%{display_name: "Home"}]
  end
end
