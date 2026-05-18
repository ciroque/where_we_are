defmodule WhereWeAre.CalendarSync.CaldavClientTest do
  use ExUnit.Case, async: true

  alias WhereWeAre.CalendarSync.CaldavClient

  defmodule FakeClient do
    def fetch_events(caldav_client, config) do
      send(config.test_pid, {:fetch_events, caldav_client})
      {:ok, []}
    end
  end

  test "connects to iCloud CalDAV with configured credentials" do
    config = %{
      apple_id: "person@example.com",
      app_password: "app-specific-password",
      test_pid: self(),
      client: FakeClient
    }

    assert {:ok, []} = CaldavClient.fetch_events(config)

    assert_receive {:fetch_events,
                    %CalDAVClient.Client{
                      server_url: "https://caldav.icloud.com",
                      auth: %CalDAVClient.Auth.Basic{
                        username: "person@example.com",
                        password: "app-specific-password"
                      }
                    }}
  end

  test "returns an error when apple id is missing" do
    assert {:error, :missing_icloud_apple_id} =
             CaldavClient.fetch_events(%{app_password: "app-specific-password", client: FakeClient})
  end

  test "returns an error when app password is missing" do
    assert {:error, :missing_icloud_app_password} =
             CaldavClient.fetch_events(%{apple_id: "person@example.com", client: FakeClient})
  end
end
