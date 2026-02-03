defmodule DemoWeb.CrashLab.Nested.CrashOnMountNestedLive do
  @moduledoc """
  A nested LiveView (rendered via live_render/3) that crashes during mount.
  No LiveRescue protection - crashes will take down this nested process.
  """
  use DemoWeb, :live_view

  @impl true
  def mount(_params, _session, _socket) do
    raise "Simulated crash in nested LiveView mount"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-4 bg-success/10 border border-success rounded-lg">
      <p class="font-medium text-success">✓ Nested LiveView mounted successfully!</p>
    </div>
    """
  end
end
