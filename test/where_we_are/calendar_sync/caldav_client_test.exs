defmodule WhereWeAre.CalendarSync.CaldavClientTest do
  use ExUnit.Case, async: true

  alias WhereWeAre.CalendarSync.CaldavClient

  defmodule FakeClient do
    def discover(caldav_client) do
      send(Process.get(:test_pid), {:discover, caldav_client})
      {:ok, :discovery_info}
    end

    def list_calendars(caldav_client, :discovery_info) do
      send(Process.get(:test_pid), {:list_calendars, caldav_client})

      {:ok,
       [
         %{url: "https://caldav.icloud.com/calendar/", display_name: "Home"},
         %{url: "https://caldav.icloud.com/work/", display_name: "Work"}
       ]}
    end

    def list_events(caldav_client, "https://caldav.icloud.com/calendar/", _opts) do
      send(Process.get(:test_pid), {:list_events, caldav_client})
      {:ok, [%{summary: "Test Event"}]}
    end
  end

  test "authenticates to CalDAV with configured credentials" do
    Process.put(:test_pid, self())

    config = %{
      username: "person@example.com",
      password: "app-specific-password",
      client: FakeClient
    }

    assert :ok = CaldavClient.authenticate(config)

    assert_receive {:discover,
                    %CalDAVEx.Client{
                      config: %CalDAVEx.Config{
                        base_url: "https://caldav.icloud.com",
                        auth: {:basic, "person@example.com", "app-specific-password"}
                      }
                    }}
  end

  test "fetch_events connects to CalDAV with configured credentials" do
    Process.put(:test_pid, self())

    config = %{
      username: "person@example.com",
      password: "app-specific-password",
      client: FakeClient,
      calendars: ["Home"]
    }

    assert {:ok, [%{summary: "Test Event", calendar_name: "Home"}]} =
             CaldavClient.fetch_events(config)

    assert_receive {:discover,
                    %CalDAVEx.Client{
                      config: %CalDAVEx.Config{base_url: "https://caldav.icloud.com"}
                    }}

    assert_receive {:list_calendars, %CalDAVEx.Client{}}
    assert_receive {:list_events, %CalDAVEx.Client{}}
  end

  test "fetch_events uses a custom CalDAV URL when provided" do
    Process.put(:test_pid, self())

    config = %{
      username: "person@example.com",
      password: "app-specific-password",
      client: FakeClient,
      url: "https://example.com/custom",
      calendars: ["Home"]
    }

    assert {:ok, [%{summary: "Test Event", calendar_name: "Home"}]} =
             CaldavClient.fetch_events(config)

    assert_receive {:discover,
                    %CalDAVEx.Client{
                      config: %CalDAVEx.Config{base_url: "https://example.com/custom"}
                    }}
  end

  test "list_calendars filters by configured calendars" do
    Process.put(:test_pid, self())

    config = %{
      username: "person@example.com",
      password: "app-specific-password",
      client: FakeClient,
      calendars: ["Home"]
    }

    assert {:ok, [%{display_name: "Home"}]} = CaldavClient.list_calendars(config)
  end

  test "list_calendars returns empty list when no calendars match filter" do
    Process.put(:test_pid, self())

    config = %{
      username: "person@example.com",
      password: "app-specific-password",
      client: FakeClient,
      calendars: ["Other"]
    }

    assert {:ok, []} = CaldavClient.list_calendars(config)
  end

  test "returns an error when username is missing" do
    assert {:error, :missing_caldav_username} =
             CaldavClient.fetch_events(%{
               password: "app-specific-password",
               client: FakeClient
             })
  end

  test "returns an error when password is missing" do
    assert {:error, :missing_caldav_password} =
             CaldavClient.fetch_events(%{username: "person@example.com", client: FakeClient})
  end
end
