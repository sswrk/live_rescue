defmodule LiveRescue.ComponentGuard do
  @moduledoc """
  Provides guarded wrappers for components.

  - `live_component_guarded/1` — runtime wrapper for LiveComponents
  - `eager_error_boundary/1` — functional component wrapper that catches render errors

  This module handles runtime creation and caching of wrapper modules that
  delegate LiveComponent callbacks to the original but wrap them with
  LiveRescue's `try/rescue` error handling.
  """

  use Phoenix.Component

  slot :inner_block, required: true

  @doc """
  Wraps content in a render error boundary. **Use as a last resort.**

  Eagerly evaluates the inner block to catch errors in functional components
  and other dynamic content. On error, renders a fallback error UI.

  This should only be used when you cannot fix the underlying component and
  need a safety net to prevent it from crashing the entire LiveView process.
  Prefer fixing the root cause of render errors over using this wrapper.

  **Trade-off:** This completely disables LiveView's change tracking for the
  wrapped content, as it forces eager evaluation of all lazy closures. Every
  render sends a full update to the client instead of a minimal diff.

      <LiveRescue.eager_error_boundary>
        <.some_component />
      </LiveRescue.eager_error_boundary>
  """
  def eager_error_boundary(assigns) do
    try do
      rendered = Phoenix.Component.__render_slot__(nil, assigns.inner_block, nil)
      force_evaluate(rendered)
      assigns = assign(assigns, :content, Phoenix.HTML.Safe.to_iodata(rendered) |> Phoenix.HTML.raw())

      ~H"{@content}"
    rescue
      e ->
        LiveRescue.log_error("render (eager_error_boundary)", e, __STACKTRACE__)
        LiveRescue.render_error(assigns)
    end
  end

  defp force_evaluate(%Phoenix.LiveView.Rendered{dynamic: dynamic}) when is_function(dynamic) do
    dynamic.(false)
    |> Enum.each(fn
      %Phoenix.LiveView.Component{} -> :ok
      %Phoenix.LiveView.Rendered{} = nested -> force_evaluate(nested)
      _other -> :ok
    end)
  end

  defp force_evaluate(_other), do: :ok

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
