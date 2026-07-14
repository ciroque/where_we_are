defmodule WhereWeAre.Calendar.Event do
  @moduledoc """
  Normalized calendar event used throughout the application.

  Construct at the CalDAV adapter boundary via `from_caldav/2` so the rest of
  the system never invents field names.
  """

  @enforce_keys [:uid, :dtstart]
  defstruct [
    :uid,
    :summary,
    :dtstart,
    :dtend,
    :location,
    :description,
    :status,
    :calendar_name,
    :calendar_color
  ]

  @type t :: %__MODULE__{
          uid: String.t(),
          summary: String.t() | nil,
          dtstart: Date.t() | DateTime.t(),
          dtend: Date.t() | DateTime.t() | nil,
          location: String.t() | nil,
          description: String.t() | nil,
          status: String.t() | nil,
          calendar_name: String.t() | nil,
          calendar_color: String.t() | nil
        }

  @doc """
  Build an event from a CalDAV/iCal map and optional calendar metadata.
  """
  def from_caldav(raw, meta \\ %{}) when is_map(raw) do
    uid =
      fetch(raw, :uid) ||
        fetch(raw, :id) ||
        generate_uid(raw)

    %__MODULE__{
      uid: to_string(uid),
      summary: fetch(raw, :summary) || fetch(raw, :title),
      dtstart: fetch(raw, :dtstart),
      dtend: fetch(raw, :dtend),
      location: fetch(raw, :location),
      description: fetch(raw, :description),
      status: fetch(raw, :status),
      calendar_name: Map.get(meta, :calendar_name) || fetch(raw, :calendar_name),
      calendar_color: Map.get(meta, :calendar_color) || fetch(raw, :calendar_color)
    }
  end

  @doc """
  Build an event from a keyword list or map used in tests and fixtures.
  """
  def new(attrs) when is_list(attrs), do: attrs |> Map.new() |> new()

  def new(attrs) when is_map(attrs) do
    from_caldav(attrs, %{
      calendar_name: Map.get(attrs, :calendar_name),
      calendar_color: Map.get(attrs, :calendar_color)
    })
  end

  defp fetch(map, key) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp generate_uid(raw) do
    :erlang.phash2({fetch(raw, :dtstart), fetch(raw, :summary), fetch(raw, :title)})
  end
end
