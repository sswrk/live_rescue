# LiveRescue

> **🚧 Early Development:** This library is a work in progress and not yet recommended for production use. APIs may change, and there are known limitations (see TODOs below).

**UX Protection from Developer Oopsies in Phoenix LiveView**

`LiveRescue` protects your users from seeing crashes caused by unexpected bugs in your code. It wraps LiveView and LiveComponent lifecycle callbacks in `try/rescue` blocks, so when something goes wrong, users see a graceful fallback instead of the "Red Screen of Death" or a jarring page reload.

**This is not an error handling library.** LiveRescue is a safety net for the bugs that slip through testing. Every error it catches should be treated as a bug to fix, not an expected condition to handle. The library logs all rescued exceptions with full stacktraces so you can find and fix them.

> **📚 Recommended Reading:** For proper error and exception handling patterns in LiveView, refer to the [official Phoenix LiveView documentation](https://hexdocs.pm/phoenix_live_view/error-handling.html).

> **⚠️ Architectural Warning:** This library overrides the standard "Let it Crash" philosophy of the BEAM. Please read the "Risks & Trade-offs" section below before using this in production.

## Installation

Add `live_rescue` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:live_rescue, git: "https://github.com/sswrk/live-rescue"}
  ]
end
```

## Usage

Add `use LiveRescue` to your LiveView or LiveComponent module:

```elixir
defmodule MyAppWeb.ThermostatLive do
  use MyAppWeb, :live_view
  use LiveRescue  # <--- Add this line

  # ...
end
```

This also works with nested LiveViews (via `live_render/3`) - each nested LiveView needs its own `use LiveRescue` since they run in separate processes.

### Global Setup

To protect all LiveViews and LiveComponents in your app, add `use LiveRescue` to your Web module:

```elixir
# lib/my_app_web.ex
def live_view do
  quote do
    use Phoenix.LiveView
    use LiveRescue  # <--- Add this line

    unquote(html_helpers())
  end
end

def live_component do
  quote do
    use Phoenix.LiveComponent
    use LiveRescue  # <--- Add this line

    unquote(html_helpers())
  end
end
```

### Nested LiveComponents

LiveRescue operates at compile time on a per-module basis. Adding `use LiveRescue` to a parent LiveView or LiveComponent does **not** automatically protect child LiveComponents rendered within it. Each component's callbacks are dispatched directly by Phoenix to that component's module — there is no interception point at the parent level.

For example, if `ParentComponent` uses LiveRescue but renders a `ChildComponent` that does not, a crash in `ChildComponent.handle_event/3` will still crash the parent LiveView process.

You have two options to protect child components:

**Option 1: Global setup** — add `use LiveRescue` to your web module's `live_component/0` function (see [Global Setup](#global-setup) above). This protects all components automatically.

**Option 2: Use `live_component_guarded`** — for cases where you can't modify the child component (e.g. third-party libraries), use the guarded wrapper in your HEEx templates:

```elixir
defmodule MyAppWeb.ParentLive do
  use MyAppWeb, :live_view
  use LiveRescue

  import LiveRescue.ComponentGuard, only: [live_component_guarded: 1]

  def render(assigns) do
    ~H"""
    <.live_component_guarded module={ThirdPartyComponent} id="tp" />
    """
  end
end
```

`live_component_guarded/1` is a drop-in replacement for `live_component/1`. At runtime, it checks whether the target module already has LiveRescue. If not, it dynamically creates a wrapper module that delegates all callbacks to the original but wraps them with LiveRescue's `try/rescue` error handling. Wrapper modules are cached in `:persistent_term` and automatically invalidated when the original module is recompiled.

> **Note:** `live_component_guarded` only protects the immediate child. If that child renders its own nested components without LiveRescue, those grandchild components remain unprotected. For full coverage across all nesting levels, use the global setup.

### Wrapped Callbacks

LiveRescue wraps the following callbacks and handles crashes differently depending on the callback type:

| Callback | Applies to | On crash |
|----------|------------|----------|
| `mount/3` | LiveView | Renders error UI instead of the view |
| `mount/1` | LiveComponent | Renders error UI instead of the component |
| `update/2` | LiveComponent | Shows flash message, keeps previous state |
| `handle_event/3` | Both | Shows flash message |
| `handle_info/2` | LiveView | Shows flash message |
| `handle_params/3` | LiveView | Shows flash message |

All crashes are logged with full stacktraces.

### Why `render/1` is not guarded

LiveRescue does **not** wrap the `render` callback with `try/rescue`. Phoenix LiveView's HEEx templates compile to `%Phoenix.LiveView.Rendered{}` structs containing lazy closures for dynamic content. These closures — including calls to functional components — are evaluated during LiveView's diff traversal, **after** the `render` function has already returned. A `try/rescue` around `render` cannot catch errors that occur in these deferred closures.

Eagerly evaluating the rendered struct to work around this would break LiveView's change tracking (diffing), which is not an acceptable tradeoff for a general-purpose library.

## Configuration

Currently, the library is not configurable.

TODO: granular configuration, the possibility to override/hook into error handlers.

## Risks & Trade-offs

LiveView follows the OTP "Let it Crash" philosophy: when something goes wrong, the process crashes and restarts with a clean state.

LiveRescue keeps the process alive instead. The socket state remains unchanged (state only updates when a callback returns successfully), but this can cause problems when a callback is supposed to reset or clean up state.

### The Stuck State Problem

Consider this flow:

```elixir
# User clicks "Submit" -> set loading state
def handle_event("submit", params, socket) do
  {:noreply, assign(socket, loading: true)}
end

# Async operation completes -> clear loading state
def handle_info({:submit_result, result}, socket) do
  do_something_that_crashes!(result)  # 💥 crashes here
  {:noreply, assign(socket, loading: false, result: result)}
end
```

Without LiveRescue: the process crashes, LiveView reconnects, `mount/3` runs again, and the user sees a fresh state.

With LiveRescue: the exception is caught, a flash message appears, but `loading` never gets set to `false`. The user sees a spinner that never goes away.

TODO: Provide a way to opt out of this or to clean up such state.
