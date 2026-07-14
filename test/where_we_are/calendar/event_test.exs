defmodule WhereWeAre.Calendar.EventTest do
  use ExUnit.Case, async: true

  alias WhereWeAre.Calendar.Event

  test "from_caldav normalizes atom keys and calendar metadata" do
    event =
      Event.from_caldav(
        %{
          uid: "abc",
          summary: "Dinner",
          dtstart: ~D[2024-01-15],
          dtend: ~D[2024-01-16],
          location: "Home",
          description: "Family",
          status: "CONFIRMED"
        },
        %{calendar_name: "Home", calendar_color: "#FF2D55FF"}
      )

    assert %Event{
             uid: "abc",
             summary: "Dinner",
             dtstart: ~D[2024-01-15],
             dtend: ~D[2024-01-16],
             location: "Home",
             description: "Family",
             status: "CONFIRMED",
             calendar_name: "Home",
             calendar_color: "#FF2D55FF"
           } = event
  end

  test "from_caldav accepts string keys and title/id aliases" do
    event =
      Event.from_caldav(%{
        "id" => "legacy",
        "title" => "Legacy Title",
        "dtstart" => ~D[2024-02-01]
      })

    assert event.uid == "legacy"
    assert event.summary == "Legacy Title"
    assert event.dtstart == ~D[2024-02-01]
  end

  test "new/1 builds from fixture-style maps" do
    event = Event.new(%{uid: "x", summary: "Y", dtstart: ~D[2024-03-01], calendar_name: "Work"})
    assert event.calendar_name == "Work"
    assert event.summary == "Y"
  end
end
