defmodule DemoWeb.CrashLabLive do
  @moduledoc """
  Standard crash lab - no LiveRescue protection.
  Crashes will take down the LiveView process.
  """
  use DemoWeb, :live_view

  alias DemoWeb.CrashLab.{
    CrashOnClickComponent,
    CrashOnUpdateComponent,
    CrashOnMountComponent,
    CrashOnRenderComponent
  }

  @impl true
  def mount(_params, _session, socket) do
    # Note: :guarded and :base_path are assigned by on_mount hook in router
    {:ok,
     socket
     |> assign(:page_title, "Crash Lab - Standard")
     |> assign(:show_mount_crasher, false)
     |> assign(:show_render_crasher, false)
     |> assign(:update_trigger, 0)}
  end

  @impl true
  def handle_event("crash_here", _params, _socket) do
    raise "Simulated crash in CrashLabLive.handle_event"
  end

  def handle_event("toggle_mount_crasher", _params, socket) do
    {:noreply, assign(socket, :show_mount_crasher, !socket.assigns.show_mount_crasher)}
  end

  def handle_event("toggle_render_crasher", _params, socket) do
    {:noreply, assign(socket, :show_render_crasher, !socket.assigns.show_render_crasher)}
  end

  def handle_event("trigger_update_crash", _params, socket) do
    {:noreply, assign(socket, :update_trigger, socket.assigns.update_trigger + 1)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <div>
        <h1 class="text-2xl font-bold flex items-center gap-2">
          Crash Lab
          <%= if @guarded do %>
            <span class="badge badge-success">LiveRescue Protected</span>
          <% else %>
            <span class="badge badge-warning">Standard (Unprotected)</span>
          <% end %>
        </h1>
        <p class="text-base-content/60 mt-1">
          <%= if @guarded do %>
            LiveRescue catches errors in callbacks - the LiveView stays alive after crashes
          <% else %>
            Standard Phoenix behavior - crashes will take down the LiveView process
          <% end %>
        </p>
      </div>

      <%!-- LiveView Crashes Section --%>
      <div class="card bg-base-100 shadow-sm border border-base-200">
        <div class="card-body">
          <h2 class="card-title text-lg flex items-center gap-2">
            <.icon name="hero-bolt" class="size-5 text-error" /> LiveView Crashes
          </h2>
          <p class="text-sm text-base-content/60 mb-4">
            These demonstrate crashes in the parent LiveView process
          </p>

          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <div class="card bg-base-200/50 border border-base-300">
              <div class="card-body p-4">
                <h3 class="font-semibold">Crash on Mount</h3>
                <p class="text-sm text-base-content/60">
                  Navigate to a LiveView that crashes during mount
                </p>
                <a href={"#{@base_path}/crash/mount"} class="btn btn-error btn-sm mt-2">
                  <.icon name="hero-arrow-right" class="size-4" /> Visit Crashing Page
                </a>
              </div>
            </div>

            <div class="card bg-base-200/50 border border-base-300">
              <div class="card-body p-4">
                <h3 class="font-semibold">Crash on Handle Event</h3>
                <p class="text-sm text-base-content/60">
                  Click this button to crash the LiveView
                </p>
                <button phx-click="crash_here" class="btn btn-error btn-sm mt-2">
                  <.icon name="hero-hand-raised" class="size-4" /> Click to Crash
                </button>
              </div>
            </div>

            <div class="card bg-base-200/50 border border-base-300">
              <div class="card-body p-4">
                <h3 class="font-semibold">Crash on Handle Params</h3>
                <p class="text-sm text-base-content/60">
                  Navigate with params that cause a crash
                </p>
                <a href={"#{@base_path}/crash/params?crash=true"} class="btn btn-error btn-sm mt-2">
                  <.icon name="hero-link" class="size-4" /> Navigate with Crash Param
                </a>
              </div>
            </div>

            <div class="card bg-base-200/50 border border-base-300">
              <div class="card-body p-4">
                <h3 class="font-semibold">Crash on Handle Info</h3>
                <p class="text-sm text-base-content/60">
                  Page crashes after a delayed message
                </p>
                <a href={"#{@base_path}/crash/delayed"} class="btn btn-error btn-sm mt-2">
                  <.icon name="hero-clock" class="size-4" /> Visit Delayed Crash
                </a>
              </div>
            </div>

            <div class="card bg-base-200/50 border border-base-300">
              <div class="card-body p-4">
                <h3 class="font-semibold">Crash on Render</h3>
                <p class="text-sm text-base-content/60">
                  Navigate to a page that crashes during render
                </p>
                <a href={"#{@base_path}/crash/render"} class="btn btn-error btn-sm mt-2">
                  <.icon name="hero-eye" class="size-4" /> Visit Render Crash
                </a>
              </div>
            </div>
          </div>
        </div>
      </div>

      <%!-- LiveComponent Crashes Section --%>
      <div class="card bg-base-100 shadow-sm border border-base-200">
        <div class="card-body">
          <h2 class="card-title text-lg flex items-center gap-2">
            <.icon name="hero-cube" class="size-5 text-warning" /> LiveComponent Crashes
          </h2>
          <p class="text-sm text-base-content/60 mb-4">
            These demonstrate crashes in child LiveComponent processes
          </p>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <%!-- Crash on Click --%>
            <div class="space-y-2">
              <h3 class="font-semibold">Component: Crash on Handle Event</h3>
              <p class="text-sm text-base-content/60">
                This component crashes when you click its button
              </p>
              <.live_component module={CrashOnClickComponent} id="crash-on-click" />
            </div>

            <%!-- Crash on Update --%>
            <div class="space-y-2">
              <h3 class="font-semibold">Component: Crash on Update</h3>
              <p class="text-sm text-base-content/60">
                This component crashes when it receives value > 3
              </p>
              <.live_component
                module={CrashOnUpdateComponent}
                id="crash-on-update"
                value={@update_trigger}
              />
              <button phx-click="trigger_update_crash" class="btn btn-warning btn-sm">
                <.icon name="hero-arrow-up" class="size-4" /> Increment Value ({@update_trigger})
              </button>
            </div>

            <%!-- Crash on Mount --%>
            <div class="space-y-2">
              <h3 class="font-semibold">Component: Crash on Mount</h3>
              <p class="text-sm text-base-content/60">
                Toggle to mount a component that crashes immediately
              </p>
              <div class="flex items-center gap-4">
                <button phx-click="toggle_mount_crasher" class="btn btn-warning btn-sm">
                  <.icon name="hero-power" class="size-4" />
                  {if @show_mount_crasher, do: "Hide", else: "Show"} Component
                </button>
                <%= if @show_mount_crasher do %>
                  <.live_component module={CrashOnMountComponent} id="crash-on-mount" />
                <% end %>
              </div>
            </div>

            <%!-- Crash on Render --%>
            <div class="space-y-2">
              <h3 class="font-semibold">Component: Crash on Render</h3>
              <p class="text-sm text-base-content/60">
                Toggle to show a component that crashes during render
              </p>
              <div class="flex items-center gap-4">
                <button phx-click="toggle_render_crasher" class="btn btn-warning btn-sm">
                  <.icon name="hero-eye" class="size-4" />
                  {if @show_render_crasher, do: "Hide", else: "Show"} Component
                </button>
                <%= if @show_render_crasher do %>
                  <.live_component module={CrashOnRenderComponent} id="crash-on-render" />
                <% end %>
              </div>
            </div>
          </div>
        </div>
      </div>

      <%!-- Nested LiveView Section --%>
      <div class="card bg-base-100 shadow-sm border border-base-200">
        <div class="card-body">
          <h2 class="card-title text-lg flex items-center gap-2">
            <.icon name="hero-squares-2x2" class="size-5 text-info" /> Nested LiveViews
          </h2>
          <p class="text-sm text-base-content/60 mb-4">
            Nested LiveViews (via live_render/3) run in their own process.
            Without LiveRescue, crashes show Phoenix error screens.
          </p>

          <div class="card bg-base-200/50 border border-base-300">
            <div class="card-body p-4">
              <h3 class="font-semibold">Test Nested LiveViews</h3>
              <p class="text-sm text-base-content/60">
                Visit the dedicated nested LiveView test page to see how standard Phoenix
                handles crashes in nested LiveViews (separate processes).
              </p>
              <a href="/crash/nested" class="btn btn-info btn-sm mt-2">
                <.icon name="hero-arrow-right" class="size-4" /> Test Nested LiveViews
              </a>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
