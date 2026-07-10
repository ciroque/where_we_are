defmodule WhereWeAreWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use WhereWeAreWeb, :html

  @calendar_colors [
    %{bg: "bg-emerald-100", text: "text-emerald-800", dot: "bg-emerald-500"},
    %{bg: "bg-sky-100", text: "text-sky-800", dot: "bg-sky-500"},
    %{bg: "bg-violet-100", text: "text-violet-800", dot: "bg-violet-500"},
    %{bg: "bg-amber-100", text: "text-amber-800", dot: "bg-amber-500"},
    %{bg: "bg-rose-100", text: "text-rose-800", dot: "bg-rose-500"},
    %{bg: "bg-teal-100", text: "text-teal-800", dot: "bg-teal-500"},
    %{bg: "bg-indigo-100", text: "text-indigo-800", dot: "bg-indigo-500"},
    %{bg: "bg-orange-100", text: "text-orange-800", dot: "bg-orange-500"},
    %{bg: "bg-pink-100", text: "text-pink-800", dot: "bg-pink-500"},
    %{bg: "bg-cyan-100", text: "text-cyan-800", dot: "bg-cyan-500"},
    %{bg: "bg-lime-100", text: "text-lime-800", dot: "bg-lime-500"},
    %{bg: "bg-fuchsia-100", text: "text-fuchsia-800", dot: "bg-fuchsia-500"}
  ]

  def calendar_color(nil), do: Enum.at(@calendar_colors, 0)

  def calendar_color(calendar_name) do
    index = :erlang.phash2(calendar_name, length(@calendar_colors))
    Enum.at(@calendar_colors, index)
  end

  def calendar_color(calendar_name, nil), do: calendar_color(calendar_name)

  def calendar_color(calendar_name, hex) when is_binary(hex) do
    # Hex colors from CalDAV are not yet supported in the UI.
    calendar_color(calendar_name)
  end

  embed_templates "page_html/*"
end
