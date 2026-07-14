defmodule WhereWeAre.CalendarFixtures do
  @moduledoc false

  alias WhereWeAre.Calendar.Event

  def event(attrs \\ %{}) do
    defaults = %{
      uid: "event-#{System.unique_integer([:positive])}",
      summary: "Test Event",
      dtstart: ~D[2024-01-15]
    }

    defaults
    |> Map.merge(Map.new(attrs))
    |> Event.new()
  end
end
