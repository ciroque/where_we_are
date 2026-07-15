defmodule WhereWeAreWeb.CalendarComponents do
  @moduledoc """
  Function components for the calendar UI.
  """
  use WhereWeAreWeb, :html

  alias WhereWeAre.Calendar.Color
  alias WhereWeAre.Calendar.Window
  alias WhereWeAreWeb.Calendar.ViewModel

  attr :month_label, :string, required: true
  attr :interactive?, :boolean, default: true

  def month_header(assigns) do
    ~H"""
    <header class="flex w-full flex-col items-center gap-6 text-center sm:flex-row sm:justify-between sm:gap-8">
      <button
        :if={@interactive?}
        type="button"
        phx-click="prev_month"
        aria-label="Move to previous month"
        class="inline-flex items-center gap-2 rounded-full border border-sky-200 bg-white px-5 py-3 text-base font-semibold text-sky-600 shadow-sm transition hover:border-sky-300 hover:bg-sky-50 cursor-pointer"
      >
        <span aria-hidden="true">←</span> Move Previous
      </button>

      <div>
        <p class="text-xs font-semibold uppercase tracking-[0.3em] text-sky-500">Where We Are</p>
        <h1 class="mt-3 text-4xl font-semibold text-zinc-900 sm:text-5xl">{@month_label}</h1>
      </div>

      <button
        :if={@interactive?}
        type="button"
        phx-click="next_month"
        aria-label="Move to next month"
        class="inline-flex items-center gap-2 rounded-full border border-sky-200 bg-white px-5 py-3 text-base font-semibold text-sky-600 shadow-sm transition hover:border-sky-300 hover:bg-sky-50 cursor-pointer"
      >
        Move Next <span aria-hidden="true">→</span>
      </button>
    </header>
    """
  end

  attr :known_calendars, :list, required: true
  attr :selected_calendars, :any, required: true
  attr :calendar_colors, :map, required: true

  def calendar_filters(assigns) do
    ~H"""
    <div class="mt-6 flex flex-wrap items-center justify-center gap-3">
      <button
        type="button"
        phx-click="today"
        aria-label="Jump to current month"
        class="inline-flex items-center gap-2 rounded-full border border-sky-200 bg-white px-5 py-3 text-base font-semibold text-sky-700 shadow-sm transition hover:border-sky-300 hover:bg-sky-50 cursor-pointer"
      >
        <span aria-hidden="true">●</span> Today
      </button>
      <%= if @known_calendars != [] do %>
        <span class="mx-2 h-6 w-px bg-zinc-200"></span>
        <%= for cal_name <- @known_calendars do %>
          <% color = Color.for_calendar(cal_name, Map.get(@calendar_colors, cal_name)) %>
          <% selected? = MapSet.member?(@selected_calendars, cal_name) %>
          <button
            type="button"
            phx-click="toggle_calendar"
            phx-value-name={cal_name}
            aria-pressed={to_string(selected?)}
            class={[
              "inline-flex items-center gap-2 rounded-full border px-4 py-2 text-sm font-medium transition cursor-pointer",
              if(selected?,
                do: [color.bg, color.text, "border-transparent"],
                else: "bg-white text-zinc-400 border-zinc-200 line-through"
              )
            ]}
            style={if(selected? && Map.get(color, :bg_style), do: "#{color.bg_style}; #{color.text_style}")}
          >
            {cal_name}
          </button>
        <% end %>
      <% end %>
    </div>
    """
  end

  attr :show?, :boolean, required: true

  def filter_notice(assigns) do
    ~H"""
    <div
      :if={@show?}
      class="mt-6 flex items-start justify-between gap-4 rounded-2xl border border-amber-200 bg-amber-50 p-4 text-amber-900"
    >
      <p class="text-sm">
        <span class="font-semibold">No calendar filter is configured.</span>
        All CalDAV calendars are currently shown. To limit which calendars appear, configure
        <code class="rounded bg-amber-100 px-1 py-0.5 font-mono text-amber-800">CALDAV_CALENDARS</code>.
      </p>
      <button
        type="button"
        phx-click="close_filter_notice"
        aria-label="Dismiss notice"
        class="shrink-0 rounded-full p-1 text-amber-700 transition hover:bg-amber-200 cursor-pointer"
      >
        <span aria-hidden="true">×</span>
      </button>
    </div>
    """
  end

  attr :last_error, :any, default: nil

  def sync_error_banner(assigns) do
    ~H"""
    <div
      :if={@last_error}
      class="mt-6 flex items-start justify-between gap-4 rounded-2xl border border-rose-200 bg-rose-50 p-4 text-rose-900"
    >
      <p class="text-sm">
        <span class="font-semibold">Calendar sync failed.</span>
        Showing the last successful data. Reason: {format_error(@last_error)}
      </p>
      <button
        type="button"
        phx-click="close_sync_error"
        aria-label="Dismiss sync error"
        class="shrink-0 rounded-full p-1 text-rose-700 transition hover:bg-rose-200 cursor-pointer"
      >
        <span aria-hidden="true">×</span>
      </button>
    </div>
    """
  end

  attr :displayed_month, :any, required: true
  attr :events, :list, required: true
  attr :timezone, :string, required: true
  attr :today, :any, required: true

  def month_grid(assigns) do
    grid = ViewModel.month_grid(assigns.displayed_month, assigns.events, assigns.timezone)
    assigns = assign(assigns, grid: grid)

    ~H"""
    <div class="mt-8 grid grid-cols-7 text-center text-xs font-semibold uppercase tracking-widest text-zinc-500 sm:text-sm">
      <span>Sun</span>
      <span>Mon</span>
      <span>Tue</span>
      <span>Wed</span>
      <span>Thu</span>
      <span>Fri</span>
      <span>Sat</span>
    </div>
    <div class="mt-2 grid grid-cols-7 gap-px rounded-2xl bg-zinc-200 text-sm text-zinc-700 sm:text-base">
      <%= for day <- @grid.cells do %>
        <% day_events = Map.get(@grid.events_by_date, day, []) %>
        <div
          class={[
            "min-h-[5rem] bg-white p-2 transition",
            day.month == @grid.first_of_month.month && "text-zinc-900",
            day.month != @grid.first_of_month.month && "text-zinc-400",
            day == @today && "bg-sky-50 text-sky-700 border-2 border-sky-400 relative z-10"
          ]}
          aria-disabled={day.month != @grid.first_of_month.month && "true"}
          tabindex={day.month != @grid.first_of_month.month && "-1"}
        >
          <time
            datetime={Date.to_iso8601(day)}
            aria-label={Calendar.strftime(day, "%A, %B %-d, %Y")}
            aria-current={day == @today && "date"}
            class="block text-right text-sm font-semibold"
          >
            {day.day}
          </time>
          <%= if day.month == @grid.first_of_month.month do %>
            <div class="mt-1 flex flex-col gap-0.5">
              <%= for event <- day_events do %>
                <% local = Window.to_local(event.dtstart, @timezone) %>
                <% color = Color.for_calendar(event.calendar_name, event.calendar_color) %>
                <button
                  type="button"
                  phx-click="show_event"
                  phx-value-uid={event.uid}
                  class={[
                    "w-full text-left flex flex-col rounded px-1.5 py-1 text-xs leading-tight cursor-pointer hover:brightness-95 transition",
                    color.bg,
                    color.text
                  ]}
                  style={if Map.get(color, :bg_style), do: "#{color.bg_style}; #{color.text_style}"}
                  title={event.summary || "Untitled"}
                >
                  <%= if is_struct(local, DateTime) do %>
                    <span class="font-bold opacity-75 text-[0.65rem]">
                      {Calendar.strftime(local, "%-I:%M %p")}
                    </span>
                  <% end %>
                  <span class="truncate">{event.summary || "Untitled"}</span>
                </button>
              <% end %>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  attr :events, :list, required: true
  attr :today, :any, required: true
  attr :timezone, :string, required: true

  def event_agenda(assigns) do
    agenda = ViewModel.agenda(assigns.events, assigns.today, assigns.timezone)
    assigns = assign(assigns, agenda: agenda)

    ~H"""
    <div class="mt-8">
      <%= if @events == [] do %>
        <p class="text-center text-zinc-400 italic">No events this month.</p>
      <% else %>
        <div class="divide-y divide-zinc-200 rounded-2xl border border-zinc-200 bg-white">
          <div class="px-5 py-3 bg-emerald-50 rounded-t-2xl">
            <h2 class="text-xs font-semibold uppercase tracking-widest text-emerald-600">
              Today &amp; Upcoming
            </h2>
          </div>
          <%= if @agenda.upcoming_events != [] do %>
            <ul class="divide-y divide-zinc-100">
              <%= for event <- @agenda.upcoming_events do %>
                <.agenda_row event={event} timezone={@timezone} muted?={false} />
              <% end %>
            </ul>
          <% else %>
            <p class="px-5 py-4 text-center text-zinc-400 italic">No upcoming events.</p>
          <% end %>
          <%= if @agenda.past_events != [] do %>
            <div class="px-5 py-3 bg-zinc-50">
              <h2 class="text-xs font-semibold uppercase tracking-widest text-zinc-400">Past</h2>
            </div>
            <ul class="divide-y divide-zinc-100">
              <%= for event <- @agenda.past_events do %>
                <.agenda_row event={event} timezone={@timezone} muted?={true} />
              <% end %>
            </ul>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  attr :event, :map, required: true
  attr :timezone, :string, required: true
  attr :muted?, :boolean, default: false

  defp agenda_row(assigns) do
    local = Window.to_local(assigns.event.dtstart, assigns.timezone)
    assigns = assign(assigns, local: local)

    ~H"""
    <li class={["flex items-center gap-4 px-5 py-4", @muted? && "opacity-60"]}>
      <time
        datetime={
          if is_struct(@local, DateTime),
            do: DateTime.to_iso8601(@local),
            else: Date.to_iso8601(@local)
        }
        class={["shrink-0 text-sm font-medium", if(@muted?, do: "text-zinc-400", else: "text-sky-600")]}
      >
        <%= if is_struct(@local, DateTime) do %>
          {Calendar.strftime(@local, "%b %-d, %-I:%M %p")}
        <% else %>
          {Calendar.strftime(@local, "%b %-d")}
        <% end %>
      </time>
      <span class={["text-base", if(@muted?, do: "text-zinc-500", else: "text-zinc-800")]}>
        {@event.summary || "Untitled"}
      </span>
    </li>
    """
  end

  attr :selected_event, :any, default: nil
  attr :timezone, :string, required: true

  def event_modal(assigns) do
    ~H"""
    <%= if @selected_event do %>
      <% ev = @selected_event
         ev_local = Window.to_local(ev.dtstart, @timezone)
         ev_end_local = if ev.dtend, do: Window.to_local(ev.dtend, @timezone), else: nil %>
      <div id="event-modal" class="fixed inset-0 z-50">
        <div class="fixed inset-0 bg-black/40 backdrop-blur-sm" phx-click="close_event"></div>
        <div class="fixed inset-0 flex items-center justify-center px-4 pointer-events-none">
          <div
            class="pointer-events-auto relative w-full max-w-md rounded-2xl bg-white shadow-2xl ring-1 ring-zinc-200 p-6"
            role="dialog"
            aria-modal="true"
            aria-labelledby="event-modal-title"
          >
            <button
              type="button"
              phx-click="close_event"
              class="absolute top-4 right-4 text-zinc-400 hover:text-zinc-600 transition cursor-pointer"
              aria-label="Close"
            >
              <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                <path
                  fill-rule="evenodd"
                  d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z"
                  clip-rule="evenodd"
                />
              </svg>
            </button>

            <div class="flex items-start gap-3 mb-4">
              <div>
                <p class="text-xs font-semibold uppercase tracking-widest text-zinc-400">
                  {ev.calendar_name || ""}
                </p>
                <h2 id="event-modal-title" class="mt-0.5 text-xl font-semibold text-zinc-900 leading-snug">
                  {ev.summary || "Untitled"}
                </h2>
              </div>
            </div>

            <dl class="space-y-2 text-sm text-zinc-700">
              <div class="flex gap-2">
                <dt class="shrink-0 font-medium text-zinc-400 w-16">Start</dt>
                <dd>
                  <%= if is_struct(ev_local, DateTime) do %>
                    {Calendar.strftime(ev_local, "%A, %B %-d, %Y at %-I:%M %p")}
                  <% else %>
                    {Calendar.strftime(ev_local, "%A, %B %-d, %Y")}
                  <% end %>
                </dd>
              </div>
              <%= if ev_end_local do %>
                <div class="flex gap-2">
                  <dt class="shrink-0 font-medium text-zinc-400 w-16">End</dt>
                  <dd>
                    <%= if is_struct(ev_end_local, DateTime) do %>
                      {Calendar.strftime(ev_end_local, "%A, %B %-d, %Y at %-I:%M %p")}
                    <% else %>
                      {Calendar.strftime(ev_end_local, "%A, %B %-d, %Y")}
                    <% end %>
                  </dd>
                </div>
              <% end %>
              <%= if present?(ev.location) do %>
                <div class="flex gap-2">
                  <dt class="shrink-0 font-medium text-zinc-400 w-16">Location</dt>
                  <dd>{ev.location}</dd>
                </div>
              <% end %>
              <%= if present?(ev.status) do %>
                <div class="flex gap-2">
                  <dt class="shrink-0 font-medium text-zinc-400 w-16">Status</dt>
                  <dd>{ev.status}</dd>
                </div>
              <% end %>
              <%= if present?(ev.description) do %>
                <div class="mt-3 pt-3 border-t border-zinc-100">
                  <dt class="font-medium text-zinc-400 mb-1">Description</dt>
                  <dd class="whitespace-pre-wrap text-zinc-600">{ev.description}</dd>
                </div>
              <% end %>
            </dl>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp present?(value), do: value != nil and value != ""

  defp format_error(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)
end
