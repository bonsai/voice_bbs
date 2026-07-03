defmodule VoiceBbsWeb.Router do
  use VoiceBbsWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {VoiceBbsWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", VoiceBbsWeb do
    pipe_through :browser

    live "/", BoardLive
  end

  scope "/", VoiceBbsWeb do
    pipe_through :api

    get "/healthz", HealthController, :index
  end

  scope "/api", VoiceBbsWeb do
    pipe_through :api

    post "/upload", UploadController, :create
  end
end
