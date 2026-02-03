defmodule DemoWeb.CrashLab.Nested.CrashOnRenderNestedLive do
  @moduledoc """
  A nested LiveView (rendered via live_render/3) that crashes during render.
  No LiveRescue protection - crashes will take down this nested process.
  """
  use DemoWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(_assigns) do
    raise "Simulated crash in nested LiveView render"
  end
end
