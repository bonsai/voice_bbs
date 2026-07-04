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
    live "/yon", YonLive
    live "/admin", AdminLive
    live "/test", TestLive
    live "/api-list", ApiLive
  end

  scope "/", VoiceBbsWeb do
    pipe_through :api

    get "/healthz", HealthController, :index
  end

  scope "/api", VoiceBbsWeb do
    pipe_through :api

    get "/posts", UploadController, :index
    get "/tree", UploadController, :tree
    post "/upload", UploadController, :create
    post "/migrate", UploadController, :migrate
    post "/create-room", UploadController, :new
    post "/new", UploadController, :new
    delete "/posts/:id", UploadController, :delete
    get "/count/:device_id", UploadController, :count
  end
end
