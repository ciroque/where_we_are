defmodule WhereWeAreWeb.PageController do
  use WhereWeAreWeb, :controller

  def home(conn, params) do
    today = conn.assigns[:today] || Date.utc_today()
    displayed_month = resolve_displayed_month(params, today)

    render(conn, :home,
      layout: false,
      today: today,
      displayed_month: displayed_month
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
end
