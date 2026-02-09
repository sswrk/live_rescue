defmodule DemoWeb.CrashLab.Guarded.CrashExternalComponent do
  use DemoWeb, :live_component

  # Note: This component does NOT use LiveRescue
  # It simulates an external component or a component from a library
  # that doesn't have built-in protection.

  @impl true
  def render(assigns) do
    ~H"""
    <div class="card bg-warning/10 border border-warning/30">
      <div class="card-body p-4">
        <div class="flex items-center justify-between">
          <div>
            <h3 class="font-semibold text-warning-content">External Component</h3>
            <p class="text-xs text-base-content/60">
              This component does NOT use LiveRescue internally. <br />
              It will be protected by the parent wrapper.
            </p>
          </div>
          <button phx-click="crash" phx-target={@myself} class="btn btn-error btn-sm">
            Crash External!
          </button>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("crash", _params, _socket) do
    raise "Simulated crash in CrashExternalComponent (no built-in LiveRescue)"
  end
end
