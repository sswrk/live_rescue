defmodule DemoWeb.CrashLab.Guarded.Nested.CrashOnRenderNestedLive do
  @moduledoc """
  A nested LiveView (rendered via live_render/3) that crashes during render.

  This tests whether LiveRescue's fallback error UI renders correctly
  inside the parent LiveView's layout.
  """
  use DemoWeb, :live_view
  use LiveRescue

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(_assigns) do
    raise "Simulated crash in nested LiveView render"
  end
end
