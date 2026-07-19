defmodule WhereWeAre.CalendarSync.Config do
  @moduledoc """
  Builds CalendarSync options from environment variables and optional config files.

  ## Sources

  For each `CALDAV_*` key, resolution order is:

  1. File `$CALDAV_CONFIG_DIR/CALDAV_*` when `CALDAV_CONFIG_DIR` is set and the file exists
  2. Process environment variable

  Mounting a Kubernetes ConfigMap as a directory under `CALDAV_CONFIG_DIR` lets
  filter knobs change without a pod restart. Call `runtime_sync_opts/0` on each
  sync (see `WhereWeAre.CalendarSync`) to pick up updates; kubelet may take up
  to ~1 minute to refresh mounted files after the ConfigMap is edited.
  """

  require Logger

  def from_env do
    [
      client: WhereWeAre.CalendarSync.CaldavClient,
      poll_interval: poll_interval_from_env(),
      event_window_months: event_window_months_from_env(),
      expand_recurrences: parse_boolean(get_var("CALDAV_EXPAND_RECURRENCES"), true),
      auth: %{
        username: get_var("CALDAV_USERNAME"),
        password: get_var("CALDAV_PASSWORD")
      },
      server: server_from_env(),
      filter: filter_from_env()
    ]
  end

  @doc """
  True when `CALDAV_CONFIG_DIR` is set (ConfigMap file mount / hot-reload path).
  """
  def config_dir_configured? do
    config_dir() != nil
  end

  @doc """
  Reloadable sync settings (safe to re-read each poll without restart).

  Includes calendar filter and event window. Auth/URL are still read at boot-time
  and are not hot-reloaded (even if present in the config dir).
  """
  def runtime_sync_opts do
    [
      event_window_months: event_window_months_from_env(),
      filter: filter_from_env()
    ]
  end

  defp poll_interval_from_env do
    minutes = parse_integer(get_var("CALDAV_POLL_MINUTES"), 10)
    :timer.minutes(max(minutes, 1))
  end

  defp event_window_months_from_env do
    parse_integer(get_var("CALDAV_EVENT_WINDOW_MONTHS"), 6)
  end

  defp server_from_env do
    case normalize_presence(get_var("CALDAV_URL")) do
      nil -> %{}
      url -> %{url: url}
    end
  end

  defp filter_from_env do
    case parse_calendars(get_var("CALDAV_CALENDARS")) do
      nil -> %{}
      calendars -> %{calendars: calendars}
    end
  end

  # Prefer a config-dir file when present so ConfigMap mounts can hot-reload.
  # Empty file content is intentional (e.g. clear calendar filter).
  defp get_var(name) when is_binary(name) do
    case config_dir() do
      nil ->
        System.get_env(name)

      dir ->
        path = Path.join(dir, name)

        case File.read(path) do
          # Strip at most one trailing line ending (\r\n, \n, or \r) that
          # ConfigMap/editors usually add. Do not String.trim/1 — that would
          # alter passwords (or other values) with intentional spaces or
          # multiple trailing newlines. replace_suffix/3 only acts once.
          {:ok, content} ->
            clear_config_read_warning(path)
            strip_one_trailing_newline(content)

          {:error, :enoent} ->
            System.get_env(name)

          {:error, reason} ->
            # Warn once per path — runtime_sync_opts/0 runs every poll.
            warn_config_read_failed_once(path, reason)
            System.get_env(name)
        end
    end
  end

  defp config_dir do
    case System.get_env("CALDAV_CONFIG_DIR") do
      nil -> nil
      "" -> nil
      dir -> dir
    end
  end

  defp config_read_failed_key(path), do: {__MODULE__, :config_read_failed, path}

  defp warn_config_read_failed_once(path, reason) do
    key = config_read_failed_key(path)

    if :persistent_term.get(key, false) != true do
      Logger.warning(
        "CALDAV config read failed for #{path}: #{inspect(reason)}; falling back to env"
      )

      :persistent_term.put(key, true)
    end
  end

  defp clear_config_read_warning(path) do
    key = config_read_failed_key(path)

    if :persistent_term.get(key, false) == true do
      :persistent_term.erase(key)
    end
  end

  # Prefer CRLF, then LF, then CR — only one match is removed.
  defp strip_one_trailing_newline(content) do
    cond do
      String.ends_with?(content, "\r\n") -> String.replace_suffix(content, "\r\n", "")
      String.ends_with?(content, "\n") -> String.replace_suffix(content, "\n", "")
      String.ends_with?(content, "\r") -> String.replace_suffix(content, "\r", "")
      true -> content
    end
  end

  defp parse_calendars(nil), do: nil
  defp parse_calendars(""), do: nil

  defp parse_calendars(calendars_string) do
    calendars_string
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> presence()
  end

  defp parse_integer(nil, default), do: default
  defp parse_integer("", default), do: default

  # Trim only for numeric knobs — passwords keep raw whitespace via get_var/1.
  defp parse_integer(value, default) when is_binary(value) do
    case value |> String.trim() |> Integer.parse() do
      {int, _} -> int
      :error -> default
    end
  end

  defp parse_boolean(nil, default), do: default
  defp parse_boolean("", default), do: default

  defp parse_boolean(value, default) when is_binary(value) do
    case String.trim(value) do
      v when v in ["true", "1"] -> true
      v when v in ["false", "0"] -> false
      _ -> default
    end
  end

  defp normalize_presence(nil), do: nil

  defp normalize_presence(value) when is_binary(value) do
    value
    |> String.trim()
    |> case do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp presence([]), do: nil
  defp presence(value), do: value
end
