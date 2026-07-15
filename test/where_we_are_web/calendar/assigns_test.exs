defmodule WhereWeAreWeb.Calendar.AssignsTest do
  use ExUnit.Case, async: true

  alias WhereWeAre.Calendar.Event
  alias WhereWeAreWeb.Calendar.Assigns

  test "resolve_timezone validates IANA names" do
    assert Assigns.resolve_timezone(%{"tz" => "America/Denver"}) == "America/Denver"
    assert Assigns.resolve_timezone(%{"tz" => "Not/AZone"}) == "Etc/UTC"
    assert Assigns.resolve_timezone(%{}) == "Etc/UTC"
  end

  test "resolve_displayed_month parses month and today params" do
    today = ~D[2024-06-15]
    assert Assigns.resolve_displayed_month(%{"month" => "2024-03-20"}, today) == ~D[2024-03-01]
    assert Assigns.resolve_displayed_month(%{"today" => "true"}, today) == ~D[2024-06-01]
    assert Assigns.resolve_displayed_month(%{}, today) == ~D[2024-06-01]
  end

  test "resolve_selected_calendars keeps only known names" do
    assert Assigns.resolve_selected_calendars(%{"selected_calendars" => "Work,Home"}, ["Work"]) ==
             ["Work"]

    assert Assigns.resolve_selected_calendars(%{"selected_calendars" => "Gone"}, ["Work"]) == :all
  end

  test "filter_events respects selected calendars" do
    events = [
      Event.new(%{uid: "1", summary: "A", dtstart: ~D[2024-01-01], calendar_name: "Work"}),
      Event.new(%{uid: "2", summary: "B", dtstart: ~D[2024-01-02], calendar_name: "Home"})
    ]

    assert [%Event{uid: "1"}] = Assigns.filter_events(events, MapSet.new(["Work"]))
  end

  test "toggle_calendar flips membership" do
    selected = MapSet.new(["Work"])
    assert Assigns.toggle_calendar(selected, "Work") == MapSet.new([])
    assert Assigns.toggle_calendar(selected, "Home") == MapSet.new(["Work", "Home"])
  end

  test "known_calendars prefers server list and falls back on error" do
    events = [
      Event.new(%{uid: "1", summary: "A", dtstart: ~D[2024-01-01], calendar_name: "FromEvent"})
    ]

    assert Assigns.known_calendars({:ok, []}, events, ["Configured"]) == ["FromEvent"]

    assert Assigns.known_calendars({:error, :down}, events, ["Configured"]) == [
             "Configured",
             "FromEvent"
           ]

    assert Assigns.known_calendars(
             {:ok, [%{display_name: "Server"}]},
             events,
             []
           ) == ["Server"]
  end

  test "known_calendars only invokes configured fun on error path" do
    events = [
      Event.new(%{uid: "1", summary: "A", dtstart: ~D[2024-01-01], calendar_name: "FromEvent"})
    ]

    assert Assigns.known_calendars({:ok, []}, events, fn ->
             flunk("configured fun should not run on {:ok, _}")
           end) == ["FromEvent"]

    assert Assigns.known_calendars({:error, :down}, events, fn -> ["Configured"] end) == [
             "Configured",
             "FromEvent"
           ]
  end
end
