defmodule DemoWeb.CrashLab.CrashingFunctional do
  @moduledoc """
  Functional components that crash during render, for testing render guards.
  """
  use Phoenix.Component

  def greeting(assigns) do
    ~H"""
    <div class="p-3 bg-success/10 rounded-lg">
      <strong>Hello!</strong> This component renders fine.
    </div>
    """
  end

  def crash_on_render(assigns) do
    raise "Simulated crash in CrashingFunctional.crash_on_render"

    ~H"""
    <div>This will never render</div>
    """
  end

  def nested_crash(assigns) do
    ~H"""
    <div class="p-3 bg-base-200 rounded-lg space-y-2">
      <strong>Nested wrapper</strong>
      <.crash_on_render />
    </div>
    """
  end
end
