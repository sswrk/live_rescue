defmodule LiveRescue do
  @moduledoc """
  LiveRescue protects LiveView and LiveComponent callbacks from crashing the process.

  It wraps `mount` (both LiveView and LiveComponent), `handle_event`, `handle_info`,
  `handle_params`, and `update` callbacks with try/rescue at compile time
  using `defoverridable`.

  When a `mount` callback crashes, LiveRescue renders a fallback error component instead
  of the normal view. For other callback crashes, a flash message is displayed.

  ## Why `render` errors are not caught

  LiveRescue does **not** wrap the `render` callback with try/rescue. Phoenix LiveView's
  HEEx templates compile to `%Phoenix.LiveView.Rendered{}` structs containing lazy closures
  for dynamic content. These closures — including calls to functional components — are
  evaluated during LiveView's diff traversal, **after** the `render` function has already
  returned. A `try/rescue` around `render` cannot catch errors that occur in these deferred
  closures.

  Eagerly evaluating the rendered struct to work around this breaks LiveView's change
  tracking (diffing), which is not an acceptable tradeoff for a general-purpose library.

  ## Flash Messages

  When a callback crashes, LiveRescue sends a `{LiveRescue, message}` message
  to the current process via `send/2`. This unified approach works for both LiveViews
  and LiveComponents (where `self()` is the parent LiveView process).

  If your LiveView uses LiveRescue, it will automatically handle this message and
  display the flash. If a parent LiveView doesn't use LiveRescue but has child
  components that do, you can add a `handle_info` clause manually:

      def handle_info({LiveRescue, message}, socket) do
        {:noreply, put_flash(socket, :error, message)}
      end
  """

  import Phoenix.Component, only: [sigil_H: 2]

  require Logger

  @private_key :__live_rescue__

  defmacro __using__(_opts) do
    quote do
      @before_compile unquote(__MODULE__)

      @doc false
      def __live_rescue__, do: true
    end
  end

  # Callback specs: {name, arity, socket_arg_position}
  @callback_specs [
    {:mount, 1, :first},
    {:mount, 3, :last},
    {:update, 2, :last},
    {:handle_event, 3, :last},
    {:handle_info, 2, :last},
    {:handle_params, 3, :last}
  ]

  defmacro __before_compile__(env) do
    definitions = Module.definitions_in(env.module, :def)

    error_handler = generate_error_message_handler()

    callback_wrappers =
      for {name, arity, socket_pos} <- @callback_specs,
          {name, arity} in definitions do
        generate_callback_wrapper(name, arity, socket_pos)
      end

    render_wrapper =
      if {:render, 1} in definitions do
        [generate_render_wrapper()]
      else
        []
      end

    [error_handler | callback_wrappers] ++ render_wrapper
  end

  # Always generate a handle_info clause to receive LiveRescue error messages
  defp generate_error_message_handler do
    socket_var = Macro.var(:socket, __MODULE__)

    quote do
      def handle_info({unquote(__MODULE__), error_message}, unquote(socket_var)) do
        {:noreply, Phoenix.LiveView.put_flash(unquote(socket_var), :error, error_message)}
      end
    end
  end

  defp generate_render_wrapper do
    quote do
      defoverridable render: 1

      def render(var!(assigns)) do
        if unquote(__MODULE__).has_error?(var!(assigns)) do
          unquote(__MODULE__).render_error(var!(assigns))
        else
          super(var!(assigns))
        end
      end
    end
  end

  defp generate_callback_wrapper(name, arity, socket_arg_position) do
    args = Macro.generate_arguments(arity, __MODULE__)

    socket_var =
      case socket_arg_position do
        :first -> List.first(args)
        :last -> List.last(args)
      end

    quote do
      defoverridable [{unquote(name), unquote(arity)}]

      def unquote(name)(unquote_splicing(args)) do
        try do
          super(unquote_splicing(args))
        rescue
          e ->
            unquote(__MODULE__).handle_crash(
              unquote(name),
              e,
              __STACKTRACE__,
              unquote(socket_var)
            )
        end
      end
    end
  end

  @doc false
  def handle_crash(:mount, e, stacktrace, socket) do
    log_error("mount", e, stacktrace)
    {:ok, put_state(socket, %{error: true})}
  end

  def handle_crash(:update, e, stacktrace, socket) do
    log_error("update", e, stacktrace)
    notify_error()
    {:ok, socket}
  end

  def handle_crash(callback, e, stacktrace, socket)
      when callback in [:handle_event, :handle_info, :handle_params] do
    log_error(Atom.to_string(callback), e, stacktrace)
    notify_error()
    {:noreply, socket}
  end

  @doc false
  def has_error?(assigns) do
    case assigns[:socket] do
      %{private: %{@private_key => %{error: true}}} -> true
      _ -> false
    end
  end

  @doc false
  def render_error(assigns) do
    ~H"""
    <div role="alert" style="padding:1rem;border:1px solid #e53e3e;border-radius:0.5rem;background:#fff5f5;color:#c53030;">
      <strong>Something went wrong.</strong>
      <p style="margin-top:0.5rem;font-size:0.875rem;">This component failed to load. Please try refreshing the page.</p>
    </div>
    """
  end

  defp put_state(socket, state) do
    Phoenix.LiveView.put_private(socket, @private_key, state)
  end

  # Sends an error message to the current process to display a flash.
  # Works for both LiveViews (self() is the LiveView) and LiveComponents
  # (self() is the parent LiveView process).
  defp notify_error do
    message = "Unexpected error"

    send(self(), {__MODULE__, message})
  end

  @doc false
  def log_error(context, exception, stacktrace) do
    formatted_stacktrace = Exception.format_stacktrace(stacktrace)

    Logger.error("""
    LiveRescue rescued #{context} error: #{Exception.message(exception)}

    #{formatted_stacktrace}\
    """)
  end

  defdelegate live_component_guarded(assigns), to: LiveRescue.ComponentGuard
end
