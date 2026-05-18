defmodule WhereWeAre.CalendarSync.ConfigTest do
  use ExUnit.Case, async: false

  alias WhereWeAre.CalendarSync.Config

  setup do
    original_apple_id = System.get_env("ICLOUD_APPLE_ID")
    original_app_password = System.get_env("ICLOUD_APP_PASSWORD")

    on_exit(fn ->
      restore_env("ICLOUD_APPLE_ID", original_apple_id)
      restore_env("ICLOUD_APP_PASSWORD", original_app_password)
    end)

    :ok
  end

  test "builds CalendarSync config from iCloud environment variables" do
    System.put_env("ICLOUD_APPLE_ID", "person@example.com")
    System.put_env("ICLOUD_APP_PASSWORD", "app-specific-password")

    assert Config.from_env() == [
             client: WhereWeAre.CalendarSync.CaldavClient,
             poll_interval: :timer.minutes(10),
             credentials: %{
               apple_id: "person@example.com",
               app_password: "app-specific-password"
             }
           ]
  end

  defp restore_env(key, nil), do: System.delete_env(key)
  defp restore_env(key, value), do: System.put_env(key, value)
end
