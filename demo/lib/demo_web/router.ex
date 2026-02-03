defmodule DemoWeb.Router do
  use DemoWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {DemoWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", DemoWeb do
    pipe_through :browser

    # Standard (unprotected) routes - use app layout
    live_session :default, on_mount: {DemoWeb.Hooks, :default}, layout: {DemoWeb.Layouts, :app} do
      live "/", CrashLabLive
      live "/crash/mount", CrashLab.CrashOnMountLive
      live "/crash/params", CrashLab.CrashOnParamsLive
      live "/crash/delayed", CrashLab.CrashOnInfoLive
      live "/crash/render", CrashLab.CrashOnRenderLive
      live "/crash/nested", CrashLab.NestedLiveViewParentLive
    end

    # LiveRescue protected routes - use app layout
    live_session :guarded, on_mount: {DemoWeb.Hooks, :guarded}, layout: {DemoWeb.Layouts, :app} do
      live "/guarded", CrashLabGuardedLive
      live "/guarded/crash/mount", CrashLab.Guarded.CrashOnMountLive
      live "/guarded/crash/params", CrashLab.Guarded.CrashOnParamsLive
      live "/guarded/crash/delayed", CrashLab.Guarded.CrashOnInfoLive
      live "/guarded/crash/render", CrashLab.Guarded.CrashOnRenderLive
      live "/guarded/crash/nested", CrashLab.Guarded.NestedLiveViewParentLive
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", DemoWeb do
  #   pipe_through :api
  # end
end
