defmodule DemoWeb.CrashLab.Guarded.Nested.CrashOnEventNestedLive do
  @moduledoc """
  A nested LiveView (rendered via live_render/3) that crashes during handle_event.

  This tests whether:
  1. LiveRescue catches handle_event errors in nested LiveViews
  2. Flash messages appear correctly in the nested LiveView's scope
  3. The parent LiveView remains functional after the nested one crashes
  """
  use DemoWeb, :live_view
  use LiveRescue

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :counter, 0)}
  end

  @impl true
  def handle_event("crash", _params, _socket) do
    raise "Simulated crash in nested LiveView handle_event"
  end

  def handle_event("increment", _params, socket) do
    {:noreply, assign(socket, :counter, socket.assigns.counter + 1)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-4 bg-base-200 border border-base-300 rounded-lg space-y-3">
      <p class="font-medium">Nested LiveView (separate process)</p>
      <p class="text-sm text-base-content/60">Counter: {@counter}</p>

      <div class="flex gap-2">
        <button phx-click="increment" class="btn btn-primary btn-sm">
          Increment
        </button>
        <button phx-click="crash" class="btn btn-error btn-sm">
          Crash Nested
        </button>
      </div>
    </div>
    """
  end
end
