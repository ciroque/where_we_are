defmodule WhereWeAre.Calendar.WindowTest do
  use ExUnit.Case, async: true

  alias WhereWeAre.Calendar.Window

  describe "end_date/2" do
    test "returns start day when dtend is absent" do
      assert Window.end_date(%{dtstart: ~D[2024-01-15]}) == ~D[2024-01-15]
    end

    test "treats Date dtend as exclusive" do
      event = %{dtstart: ~D[2024-01-15], dtend: ~D[2024-01-16]}
      assert Window.end_date(event) == ~D[2024-01-15]
    end

    test "treats DateTime dtend as exclusive" do
      event = %{
        dtstart: DateTime.new!(~D[2024-01-15], ~T[10:00:00], "Etc/UTC"),
        dtend: DateTime.new!(~D[2024-01-16], ~T[00:00:00], "Etc/UTC")
      }

      assert Window.end_date(event) == ~D[2024-01-15]
    end

    test "falls back to start when computed end is earlier than start" do
      event = %{dtstart: ~D[2024-01-15], dtend: ~D[2024-01-15]}
      assert Window.end_date(event) == ~D[2024-01-15]
    end
  end

  describe "days_in_range/4" do
    test "returns a single day for an event with no dtend" do
      assert [~D[2024-01-15]] =
               Window.days_in_range(%{dtstart: ~D[2024-01-15]}, "Etc/UTC")
    end

    test "expands a multi-day event across every day it spans" do
      event = %{dtstart: ~D[2024-01-15], dtend: ~D[2024-01-18]}

      assert [
               ~D[2024-01-15],
               ~D[2024-01-16],
               ~D[2024-01-17]
             ] = Window.days_in_range(event, "Etc/UTC")
    end

    test "treats Date dtend as exclusive" do
      event = %{dtstart: ~D[2024-01-15], dtend: ~D[2024-01-16]}
      assert [~D[2024-01-15]] = Window.days_in_range(event, "Etc/UTC")
    end

    test "treats DateTime dtend as exclusive" do
      event = %{
        dtstart: DateTime.new!(~D[2024-01-15], ~T[10:00:00], "Etc/UTC"),
        dtend: DateTime.new!(~D[2024-01-16], ~T[00:00:00], "Etc/UTC")
      }

      assert [~D[2024-01-15]] = Window.days_in_range(event, "Etc/UTC")
    end

    test "expands DateTime events across multiple days in the target timezone" do
      event = %{
        dtstart: DateTime.new!(~D[2024-01-15], ~T[10:00:00], "Etc/UTC"),
        dtend: DateTime.new!(~D[2024-01-17], ~T[10:00:00], "Etc/UTC")
      }

      assert [
               ~D[2024-01-15],
               ~D[2024-01-16],
               ~D[2024-01-17]
             ] = Window.days_in_range(event, "Etc/UTC")
    end

    test "falls back to start when computed end is earlier than start" do
      event = %{dtstart: ~D[2024-01-15], dtend: ~D[2024-01-15]}
      assert [~D[2024-01-15]] = Window.days_in_range(event, "Etc/UTC")
    end

    test "clamps days to the provided grid window" do
      event = %{dtstart: ~D[2024-01-01], dtend: ~D[2024-01-10]}

      assert [~D[2024-01-05], ~D[2024-01-06]] =
               Window.days_in_range(event, "Etc/UTC", ~D[2024-01-05], ~D[2024-01-06])
    end
  end

  describe "overlaps_range?/4 and events_for_month/3" do
    test "returns events starting within the month when dtstart is a DateTime" do
      events = [
        %{id: "jan-early", dtstart: DateTime.new!(~D[2024-01-05], ~T[09:00:00], "Etc/UTC")},
        %{id: "feb-start", dtstart: DateTime.new!(~D[2024-02-01], ~T[08:00:00], "Etc/UTC")},
        %{id: "jan-late", dtstart: DateTime.new!(~D[2024-01-31], ~T[18:30:00], "Etc/UTC")}
      ]

      assert [%{id: "jan-early"}, %{id: "jan-late"}] =
               Window.events_for_month(events, ~D[2024-01-01])
    end

    test "filters DateTime events using the viewer timezone near month boundaries" do
      # 2024-02-01 02:00 UTC == 2024-01-31 19:00 America/Denver
      events = [
        %{id: "local-jan", dtstart: DateTime.new!(~D[2024-02-01], ~T[02:00:00], "Etc/UTC")}
      ]

      assert [%{id: "local-jan"}] =
               Window.events_for_month(events, ~D[2024-01-01], "America/Denver")

      assert [] = Window.events_for_month(events, ~D[2024-01-01], "Etc/UTC")

      assert [] = Window.events_for_month(events, ~D[2024-02-01], "America/Denver")

      assert [%{id: "local-jan"}] =
               Window.events_for_month(events, ~D[2024-02-01], "Etc/UTC")
    end

    test "filters by both month and year" do
      events = [
        %{id: "may-2025", dtstart: DateTime.new!(~D[2025-05-10], ~T[10:00:00], "Etc/UTC")},
        %{id: "may-2026", dtstart: DateTime.new!(~D[2026-05-10], ~T[10:00:00], "Etc/UTC")},
        %{id: "june-2026", dtstart: DateTime.new!(~D[2026-06-01], ~T[08:00:00], "Etc/UTC")}
      ]

      assert [%{id: "may-2026"}] = Window.events_for_month(events, ~D[2026-05-01])
      assert [%{id: "may-2025"}] = Window.events_for_month(events, ~D[2025-05-01])
    end

    test "supports Date dtstart and ignores events missing dtstart" do
      events = [
        %{id: "with-date", dtstart: ~D[2024-01-10]},
        %{id: "missing-date"}
      ]

      assert [%{id: "with-date"}] = Window.events_for_month(events, ~D[2024-01-01])
      assert [] = Window.events_for_month(events, ~D[2024-02-01])
    end

    test "includes multi-day events overlapping the month" do
      events = [
        %{id: "starts-before-ends-inside", dtstart: ~D[2023-12-28], dtend: ~D[2024-01-03]},
        %{id: "starts-inside-ends-after", dtstart: ~D[2024-01-28], dtend: ~D[2024-02-03]},
        %{id: "spans-month", dtstart: ~D[2023-12-15], dtend: ~D[2024-02-15]},
        %{id: "before", dtstart: ~D[2023-12-01], dtend: ~D[2023-12-02]},
        %{id: "after", dtstart: ~D[2024-02-01], dtend: ~D[2024-02-02]}
      ]

      assert [
               %{id: "spans-month"},
               %{id: "starts-before-ends-inside"},
               %{id: "starts-inside-ends-after"}
             ] = Window.events_for_month(events, ~D[2024-01-01])
    end

    test "handles exclusive dtend with Date values" do
      events = [
        %{id: "last-day", dtstart: ~D[2024-01-31], dtend: ~D[2024-02-01]},
        %{id: "exclusive-starts-feb", dtstart: ~D[2024-02-01], dtend: ~D[2024-02-02]}
      ]

      assert [%{id: "last-day"}] = Window.events_for_month(events, ~D[2024-01-01])
      assert [%{id: "exclusive-starts-feb"}] = Window.events_for_month(events, ~D[2024-02-01])
    end

    test "handles exclusive dtend with DateTime values" do
      events = [
        %{
          id: "last-day",
          dtstart: DateTime.new!(~D[2024-01-31], ~T[23:00:00], "Etc/UTC"),
          dtend: DateTime.new!(~D[2024-02-01], ~T[00:00:00], "Etc/UTC")
        },
        %{
          id: "exclusive-starts-feb",
          dtstart: DateTime.new!(~D[2024-02-01], ~T[00:00:00], "Etc/UTC"),
          dtend: DateTime.new!(~D[2024-02-02], ~T[00:00:00], "Etc/UTC")
        }
      ]

      assert [%{id: "last-day"}] = Window.events_for_month(events, ~D[2024-01-01])
      assert [%{id: "exclusive-starts-feb"}] = Window.events_for_month(events, ~D[2024-02-01])
    end
  end

  describe "split_past_upcoming/3" do
    test "splits by inclusive end date relative to today" do
      events = [
        %{id: "past", dtstart: ~D[2024-01-01], dtend: ~D[2024-01-02]},
        %{id: "today", dtstart: ~D[2024-01-15]},
        %{id: "future", dtstart: ~D[2024-01-20]}
      ]

      assert {[%{id: "past"}], [%{id: "today"}, %{id: "future"}]} =
               Window.split_past_upcoming(events, ~D[2024-01-15])
    end
  end
end
