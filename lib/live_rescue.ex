defmodule LiveRescue do
  @moduledoc """
  LiveRescue protects LiveView and LiveComponent callbacks from crashing the process.

  It wraps `mount` (both LiveView and LiveComponent), `handle_event`, `handle_info`,
  `handle_params`, `update`, and `render` callbacks with try/rescue at compile time
  using `defoverridable`.

  ## Internal State

  LiveRescue stores its internal state in the `__live_rescue__` assign key. This is
  a reserved key that should not be modified directly by user code.
  """

  require Logger

  import Phoenix.Component, only: [sigil_H: 2]

  @private_key :__live_rescue__

  defmacro __using__(_opts) do
    quote do
      @before_compile unquote(__MODULE__)
    end
  end

  # Callback specs: {name, arity, socket_arg_position}
  @callback_specs [
    {:mount, 1, :first},
    {:mount, 3, :last},
    {:update, 2, :last},
    {:handle_event, 3, :last},
    {:handle_info, 2, :last},
    {:handle_params, 3, :last},
    {:render, 1, :first}
  ]

  defmacro __before_compile__(env) do
    definitions = Module.definitions_in(env.module, :def)

    for {name, arity, socket_pos} <- @callback_specs,
        {name, arity} in definitions do
      generate_callback_wrapper(name, arity, socket_pos)
    end
  end

  defp generate_callback_wrapper(:render, 1, :first) do
    assigns_var = Macro.var(:assigns, __MODULE__)

    quote do
      defoverridable render: 1

      def render(unquote(assigns_var)) do
        if unquote(__MODULE__).has_error?(unquote(assigns_var)) do
          unquote(__MODULE__).render_error(unquote(assigns_var))
        else
          try do
            super(unquote(assigns_var))
          rescue
            e ->
              unquote(__MODULE__).handle_crash(:render, e, __STACKTRACE__, unquote(assigns_var))
          end
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
  def has_error?(assigns), do: !!assigns[@private_key][:error]

  @doc false
  def render_error(assigns) do
    ~H"""
    <div class="p-4 bg-error/10 border border-error/30 rounded-lg text-error">
      <p class="font-medium">Unexpected error</p>
    </div>
    """
  end

  @doc false
  def handle_crash(:mount, e, stacktrace, socket) do
    log_error("mount", e, stacktrace)
    {:ok, put_state(socket, %{error: true})}
  end

  def handle_crash(:update, e, stacktrace, socket) do
    log_error("update", e, stacktrace)
    {:ok, Phoenix.LiveView.put_flash(socket, :error, "Unexpected error")}
  end

  def handle_crash(:render, e, stacktrace, assigns) do
    log_error("render", e, stacktrace)
    render_error(assigns)
  end

  def handle_crash(callback, e, stacktrace, socket)
      when callback in [:handle_event, :handle_info, :handle_params] do
    log_error(Atom.to_string(callback), e, stacktrace)
    {:noreply, Phoenix.LiveView.put_flash(socket, :error, "Unexpected error")}
  end

  @doc false
  def log_error(context, exception, stacktrace) do
    formatted_stacktrace = Exception.format_stacktrace(stacktrace)

    Logger.error("""
    LiveRescue rescued #{context} error: #{Exception.message(exception)}

    #{formatted_stacktrace}\
    """)
  end

  # Private helpers for managing LiveRescue's internal state

  defp put_state(socket, state) when is_map(state) do
    current = Map.get(socket.assigns, @private_key, %{})
    Phoenix.Component.assign(socket, @private_key, Map.merge(current, state))
  end
end
