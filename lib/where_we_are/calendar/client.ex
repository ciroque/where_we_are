defmodule WhereWeAre.Calendar.Client do
  @moduledoc """
  Behaviour for calendar backends used by `WhereWeAre.CalendarSync`.
  """

  alias WhereWeAre.Calendar.Event

  @type calendar_info :: %{
          required(:display_name) => String.t(),
          optional(:color) => String.t() | nil,
          optional(:url) => String.t(),
          optional(atom()) => term()
        }

  @type config :: map()

  @callback fetch_events(config()) :: {:ok, [Event.t()]} | {:error, term()}
  @callback list_calendars(config()) :: {:ok, [calendar_info()]} | {:error, term()}
end
