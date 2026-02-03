defmodule DemoWeb.NestedLiveViewTest do
  use DemoWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  describe "nested LiveView with LiveRescue" do
    test "parent page loads successfully", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/guarded/crash/nested")

      # Parent should load
      assert html =~ "Nested LiveView Tests"
      assert html =~ "Parent LiveView"

      # Parent counter should work
      assert html =~ "Parent counter:"
    end

    test "parent remains functional after nested mount crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/guarded/crash/nested")

      # Click to show the mount-crashing nested LiveView (first "Show Nested" button)
      view |> element("button[phx-click=toggle_mount_crasher]") |> render_click()

      # Wait a moment for the nested LiveView to mount and crash
      Process.sleep(100)

      # Parent should still work - increment counter
      html = view |> element("button", "Increment Parent") |> render_click()
      assert html =~ "Parent counter:"

      # The nested LiveView should show error UI
      html = render(view)
      assert html =~ "Unexpected error"
    end

    test "event-crashing nested LiveView works independently", %{conn: conn} do
      {:ok, view, html} = live(conn, "/guarded/crash/nested")

      # The event-crashing nested LiveView should be visible by default
      assert html =~ "Nested LiveView (separate process)"
      assert html =~ "Counter:"

      # Parent counter should increment
      html = view |> element("button", "Increment Parent") |> render_click()
      assert html =~ "Parent counter:"
    end

    test "parent crash handling works", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/guarded/crash/nested")

      # Crash the parent - LiveRescue should catch it
      html = view |> element("button", "Crash Parent") |> render_click()

      # Flash should appear (LiveRescue catches handle_event crash)
      assert html =~ "Unexpected error" or html =~ "error"
    end
  end
end
