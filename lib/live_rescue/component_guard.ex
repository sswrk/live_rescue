defmodule LiveRescue.ComponentGuard do
  @moduledoc """
  Provides guarded versions of `Phoenix.Component.live_component/1`.

  This module handles runtime creation and caching of wrapper modules that
  delegate LiveComponent callbacks to the original but wrap them with
  LiveRescue's `try/rescue` error handling.
  """

  @doc """
  A guarded version of `Phoenix.Component.live_component/1`.

  Use this in HEEx templates as a drop-in replacement for `live_component`
  to automatically protect any LiveComponent with LiveRescue — even components
  that don't `use LiveRescue` themselves.

      <.live_component_guarded module={SomeComponent} id="example" />

  At runtime, if the target module doesn't already have LiveRescue, a wrapper
  module is created (and cached) that delegates all callbacks to the original
  but wraps them with LiveRescue's `try/rescue` error handling.

  Import this function where needed:

      import LiveRescue.ComponentGuard, only: [live_component_guarded: 1]

  Or add it to your web module helpers so it's available in all templates.
  """
  def live_component_guarded(assigns) do
    module = assigns[:module]

    if module && !function_exported?(module, :__live_rescue__, 0) do
      guarded = get_or_create_guarded(module)
      Phoenix.Component.live_component(Map.put(assigns, :module, guarded))
    else
      Phoenix.Component.live_component(assigns)
    end
  end

  @guarded_callbacks [{:mount, 1}, {:update, 2}, {:handle_event, 3}, {:render, 1}]

  defp get_or_create_guarded(module) do
    key = {__MODULE__, :guarded, module}
    md5 = module.module_info(:md5)

    case :persistent_term.get(key, nil) do
      {^md5, wrapper} ->
        wrapper

      _ ->
        wrapper = create_guarded_module(module)
        :persistent_term.put(key, {md5, wrapper})
        wrapper
    end
  end

  defp create_guarded_module(inner) do
    wrapper_name = Module.concat(LiveRescue.Guarded, inner)

    # Purge any stale version of this module (from a previous code reload)
    :code.purge(wrapper_name)
    :code.delete(wrapper_name)

    callbacks =
      for {cb, arity} <- @guarded_callbacks,
          function_exported?(inner, cb, arity),
          do: cb

    contents =
      quote do
        use Phoenix.LiveComponent
        use LiveRescue

        if :mount in unquote(callbacks) do
          @impl true
          def mount(socket), do: unquote(inner).mount(socket)
        end

        if :update in unquote(callbacks) do
          @impl true
          def update(assigns, socket), do: unquote(inner).update(assigns, socket)
        end

        if :handle_event in unquote(callbacks) do
          @impl true
          def handle_event(event, params, socket),
            do: unquote(inner).handle_event(event, params, socket)
        end

        if :render in unquote(callbacks) do
          @impl true
          def render(assigns), do: unquote(inner).render(assigns)
        end
      end

    Module.create(wrapper_name, contents, file: "live_rescue/guarded", line: 1)
    wrapper_name
  end
end
