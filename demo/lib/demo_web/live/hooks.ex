defmodule DemoWeb.Hooks do
  @moduledoc """
  on_mount hooks for the demo app.

  These hooks assign values that the layout depends on, simulating a real-world
  scenario where on_mount sets things like current_user, locale, etc.
  """

  import Phoenix.Component, only: [assign: 3]

  def on_mount(:default, _params, _session, socket) do
    {:cont, assign(socket, :guarded, false) |> assign(:base_path, "")}
  end

  def on_mount(:guarded, _params, _session, socket) do
    {:cont, assign(socket, :guarded, true) |> assign(:base_path, "/guarded")}
  end
end
