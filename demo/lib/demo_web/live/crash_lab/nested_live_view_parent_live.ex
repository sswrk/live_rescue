defmodule DemoWeb.CrashLab.NestedLiveViewParentLive do
  @moduledoc """
  Parent LiveView that hosts nested LiveViews via live_render/3.
  No LiveRescue protection - crashes will take down the LiveView process.

  This demonstrates standard Phoenix behavior with nested LiveViews:
  - Nested LiveViews run in their own process
  - Crashes in nested LiveViews don't affect the parent process
  - But there's no graceful error handling - users see error screens
  """
  use DemoWeb, :live_view

  alias DemoWeb.CrashLab.Nested.{
    CrashOnMountNestedLive,
    CrashOnEventNestedLive,
    CrashOnRenderNestedLive
  }

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Nested LiveView Tests")
     |> assign(:parent_counter, 0)
     |> assign(:show_mount_crasher, false)
     |> assign(:show_render_crasher, false)}
  end

  @impl true
  def handle_event("parent_increment", _params, socket) do
    {:noreply, assign(socket, :parent_counter, socket.assigns.parent_counter + 1)}
  end

  def handle_event("parent_crash", _params, _socket) do
    raise "Simulated crash in parent LiveView"
  end

  def handle_event("toggle_mount_crasher", _params, socket) do
    {:noreply, assign(socket, :show_mount_crasher, !socket.assigns.show_mount_crasher)}
  end

  def handle_event("toggle_render_crasher", _params, socket) do
    {:noreply, assign(socket, :show_render_crasher, !socket.assigns.show_render_crasher)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <div>
        <h1 class="text-2xl font-bold flex items-center gap-2">
          Nested LiveView Tests <span class="badge badge-warning">Standard (Unprotected)</span>
        </h1>
        <p class="text-base-content/60 mt-1">
          Testing standard Phoenix behavior with nested LiveViews (via live_render/3).
          Each nested LiveView runs in its own process - crashes show error screens.
        </p>
        <a href="/" class="btn btn-ghost btn-sm mt-2">
          <.icon name="hero-arrow-left" class="size-4" /> Back to Crash Lab
        </a>
      </div>

      <%!-- Parent LiveView Status --%>
      <div class="card bg-base-100 shadow-sm border border-base-200">
        <div class="card-body">
          <h2 class="card-title text-lg flex items-center gap-2">
            <.icon name="hero-window" class="size-5 text-primary" /> Parent LiveView
          </h2>
          <p class="text-sm text-base-content/60 mb-4">
            This is the parent LiveView. It should continue working even when nested LiveViews crash
            (since they're separate processes).
          </p>

          <div class="flex items-center gap-4">
            <span class="text-sm">Parent counter: <strong>{@parent_counter}</strong></span>
            <button phx-click="parent_increment" class="btn btn-primary btn-sm">
              Increment Parent
            </button>
            <button phx-click="parent_crash" class="btn btn-error btn-sm">
              Crash Parent
            </button>
          </div>
        </div>
      </div>

      <%!-- Nested LiveViews Section --%>
      <div class="card bg-base-100 shadow-sm border border-base-200">
        <div class="card-body">
          <h2 class="card-title text-lg flex items-center gap-2">
            <.icon name="hero-squares-2x2" class="size-5 text-warning" />
            Nested LiveViews (live_render/3)
          </h2>
          <p class="text-sm text-base-content/60 mb-4">
            These are nested LiveViews, each running in their own process.
            Without LiveRescue, crashes show Phoenix error screens.
          </p>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <%!-- Crash on Handle Event (always visible) --%>
            <div class="space-y-2">
              <h3 class="font-semibold">Nested: Crash on Handle Event</h3>
              <p class="text-sm text-base-content/60">
                This nested LiveView crashes when you click "Crash Nested".
                The nested process will die and show an error.
              </p>
              <div class="border border-dashed border-base-300 rounded-lg p-2">
                {live_render(@socket, CrashOnEventNestedLive, id: "nested-event-crash")}
              </div>
            </div>

            <%!-- Crash on Mount (toggleable) --%>
            <div class="space-y-2">
              <h3 class="font-semibold">Nested: Crash on Mount</h3>
              <p class="text-sm text-base-content/60">
                Toggle to mount a nested LiveView that crashes immediately.
                The parent should remain functional.
              </p>
              <div class="flex items-center gap-4">
                <button phx-click="toggle_mount_crasher" class="btn btn-warning btn-sm">
                  <.icon name="hero-power" class="size-4" />
                  {if @show_mount_crasher, do: "Hide", else: "Show"} Nested
                </button>
              </div>
              <%= if @show_mount_crasher do %>
                <div class="border border-dashed border-base-300 rounded-lg p-2">
                  {live_render(@socket, CrashOnMountNestedLive, id: "nested-mount-crash")}
                </div>
              <% end %>
            </div>

            <%!-- Crash on Render (toggleable) --%>
            <div class="space-y-2">
              <h3 class="font-semibold">Nested: Crash on Render</h3>
              <p class="text-sm text-base-content/60">
                Toggle to show a nested LiveView that crashes during render.
                An error will appear inside this container.
              </p>
              <div class="flex items-center gap-4">
                <button phx-click="toggle_render_crasher" class="btn btn-warning btn-sm">
                  <.icon name="hero-eye" class="size-4" />
                  {if @show_render_crasher, do: "Hide", else: "Show"} Nested
                </button>
              </div>
              <%= if @show_render_crasher do %>
                <div class="border border-dashed border-base-300 rounded-lg p-2">
                  {live_render(@socket, CrashOnRenderNestedLive, id: "nested-render-crash")}
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>

      <%!-- Behavior Documentation --%>
      <div class="card bg-warning/10 border border-warning/20">
        <div class="card-body">
          <h2 class="card-title text-lg flex items-center gap-2">
            <.icon name="hero-exclamation-triangle" class="size-5 text-warning" /> Expected Behavior
          </h2>
          <ul class="list-disc list-inside text-sm space-y-1 text-base-content/80">
            <li>
              <strong>Crash on Mount:</strong>
              Nested LiveView shows Phoenix error screen, parent continues working
            </li>
            <li>
              <strong>Crash on Handle Event:</strong>
              Nested process dies, shows error or triggers reconnection
            </li>
            <li>
              <strong>Crash on Render:</strong> Error screen replaces the nested LiveView content
            </li>
            <li>
              <strong>Parent Independence:</strong>
              Parent counter and controls work regardless of nested crashes
            </li>
            <li>
              <strong>Process Isolation:</strong>
              Each nested LiveView is a separate process (standard Phoenix)
            </li>
          </ul>
        </div>
      </div>
    </div>
    """
  end
end
