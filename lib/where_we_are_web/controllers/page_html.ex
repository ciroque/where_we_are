defmodule WhereWeAreWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use WhereWeAreWeb, :html

  @calendar_colors [
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

  def calendar_color(nil), do: Enum.at(@calendar_colors, 0)

  def calendar_color(calendar_name) do
    index = :erlang.phash2(calendar_name, length(@calendar_colors))
    Enum.at(@calendar_colors, index)
  end

  def calendar_color(calendar_name, nil), do: calendar_color(calendar_name)

  def calendar_color(calendar_name, hex) when is_binary(hex) do
    rgb = normalize_hex(hex)
    base = calendar_color(calendar_name)

    base
    |> Map.put(:bg, nil)
    |> Map.put(:text, nil)
    |> Map.put(:bg_style, "background-color: #{rgb}")
    |> Map.put(:text_style, "color: #{text_color_for_hex(rgb)}")
  end

  defp normalize_hex("#" <> rest) when byte_size(rest) == 8 do
    "#" <> binary_part(rest, 0, 6)
  end

  defp normalize_hex(hex), do: hex

  defp text_color_for_hex("#" <> rgb) when byte_size(rgb) == 6 do
    {r, _} = Integer.parse(binary_part(rgb, 0, 2), 16)
    {g, _} = Integer.parse(binary_part(rgb, 2, 2), 16)
    {b, _} = Integer.parse(binary_part(rgb, 4, 2), 16)
    luminance = 0.2126 * r / 255 + 0.7152 * g / 255 + 0.0722 * b / 255
    if luminance > 0.4, do: "#111827", else: "#ffffff"
  end

  defp text_color_for_hex(_hex), do: "#111827"

  embed_templates "page_html/*"
end
