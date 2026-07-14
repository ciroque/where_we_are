defmodule WhereWeAre.Calendar.Color do
  @moduledoc """
  Calendar color palette and hex contrast helpers.

  Pure domain logic — no Phoenix dependency.
  """

  @palette [
    %{bg: "bg-emerald-100", text: "text-emerald-800"},
    %{bg: "bg-sky-100", text: "text-sky-800"},
    %{bg: "bg-violet-100", text: "text-violet-800"},
    %{bg: "bg-amber-100", text: "text-amber-800"},
    %{bg: "bg-rose-100", text: "text-rose-800"},
    %{bg: "bg-teal-100", text: "text-teal-800"},
    %{bg: "bg-indigo-100", text: "text-indigo-800"},
    %{bg: "bg-orange-100", text: "text-orange-800"},
    %{bg: "bg-pink-100", text: "text-pink-800"},
    %{bg: "bg-cyan-100", text: "text-cyan-800"},
    %{bg: "bg-lime-100", text: "text-lime-800"},
    %{bg: "bg-fuchsia-100", text: "text-fuchsia-800"}
  ]

  @hex_chars ~r/^#[0-9a-fA-F]{6}$/

  @doc """
  Resolve display colors for a calendar name, optionally with a CalDAV hex.
  """
  def for_calendar(nil), do: Enum.at(@palette, 0)

  def for_calendar(calendar_name) do
    index = :erlang.phash2(calendar_name, length(@palette))
    Enum.at(@palette, index)
  end

  def for_calendar(calendar_name, nil), do: for_calendar(calendar_name)

  def for_calendar(calendar_name, hex) when is_binary(hex) do
    case normalize_hex(hex) do
      nil ->
        for_calendar(calendar_name)

      rgb ->
        calendar_name
        |> for_calendar()
        |> Map.put(:bg, nil)
        |> Map.put(:text, nil)
        |> Map.put(:bg_style, "background-color: #{rgb}")
        |> Map.put(:text_style, "color: #{text_color_for_hex(rgb)}")
    end
  end

  defp normalize_hex("#" <> rest) when byte_size(rest) == 8 do
    normalize_hex("#" <> binary_part(rest, 0, 6))
  end

  defp normalize_hex(hex) do
    if Regex.match?(@hex_chars, hex), do: hex, else: nil
  end

  defp text_color_for_hex("#" <> rgb) do
    {r, _} = Integer.parse(binary_part(rgb, 0, 2), 16)
    {g, _} = Integer.parse(binary_part(rgb, 2, 2), 16)
    {b, _} = Integer.parse(binary_part(rgb, 4, 2), 16)
    luminance = 0.2126 * r / 255 + 0.7152 * g / 255 + 0.0722 * b / 255
    if luminance > 0.4, do: "#111827", else: "#ffffff"
  end
end
