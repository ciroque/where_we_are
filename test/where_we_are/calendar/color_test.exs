defmodule WhereWeAre.Calendar.ColorTest do
  use ExUnit.Case, async: true

  alias WhereWeAre.Calendar.Color

  test "returns bg_style and text_style for an 8-char CalDAV hex" do
    color = Color.for_calendar("My Calendar", "#FF2D55FF")
    assert color.bg_style == "background-color: #FF2D55"
    assert color.text_style == "color: #ffffff"
    assert color.bg == nil
    assert color.text == nil
  end

  test "returns bg_style and text_style for a 6-char hex" do
    color = Color.for_calendar("My Calendar", "#FF2D55")
    assert color.bg_style == "background-color: #FF2D55"
    assert color.text_style == "color: #ffffff"
  end

  test "picks dark text for a light hex color" do
    color = Color.for_calendar("My Calendar", "#FFFFFF")
    assert color.text_style == "color: #111827"
  end

  test "falls back to Tailwind classes when hex is invalid" do
    color = Color.for_calendar("My Calendar", "red; background: evil")
    assert is_binary(color.bg)
    refute Map.has_key?(color, :bg_style)
  end

  test "falls back to Tailwind classes when hex is nil" do
    color = Color.for_calendar("My Calendar", nil)
    assert is_binary(color.bg)
    assert is_binary(color.text)
    refute Map.has_key?(color, :bg_style)
  end

  test "falls back to Tailwind classes when name is nil" do
    color = Color.for_calendar(nil)
    assert is_binary(color.bg)
    assert is_binary(color.text)
  end
end
