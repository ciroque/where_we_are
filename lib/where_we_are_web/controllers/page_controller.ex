defmodule WhereWeAreWeb.PageController do
  use WhereWeAreWeb, :controller

  def home(conn, params) do
    today = conn.assigns[:today] || Date.utc_today()
    displayed_month = resolve_displayed_month(params, today)

    events =
      conn.assigns[:events] ||
        WhereWeAre.CalendarSync.events_for_month(
          WhereWeAre.CalendarSync,
          displayed_month
        )

    event_dates =
      events
      |> Enum.map(&event_date/1)
      |> Enum.reject(&is_nil/1)
      |> MapSet.new()

    render(conn, :home,
      layout: false,
      today: today,
      displayed_month: displayed_month,
      events: events,
      event_dates: event_dates
    )
  end

  defp resolve_displayed_month(%{"today" => "true"}, today) do
    Date.beginning_of_month(today)
  end

  defp resolve_displayed_month(%{"month" => month_param}, today) when is_binary(month_param) do
    month_param
    |> Date.from_iso8601()
    |> case do
      {:ok, date} -> Date.beginning_of_month(date)
      _error -> Date.beginning_of_month(today)
    end
  end

  defp resolve_displayed_month(_params, today) do
    Date.beginning_of_month(today)
  end

  defp event_date(%{dtstart: %DateTime{} = dt}), do: DateTime.to_date(dt)
  defp event_date(%{dtstart: %Date{} = date}), do: date
  defp event_date(_), do: nil
end
