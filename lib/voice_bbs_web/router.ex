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

  pipeline :api_auth do
    plug :accepts, ["json"]
    plug VoiceBbsWeb.Plugs.Auth
  end

  scope "/", VoiceBbsWeb do
    pipe_through :browser

    live "/", LandingLive
    live "/manage", ManageLive
    live "/room/:id", RoomLive
    live "/shiritori", ShiritoriLive
  end

  scope "/api", VoiceBbsWeb do
    pipe_through :api

    get "/healthz", HealthController, :index
    get "/posts", UploadController, :index
    get "/tree", UploadController, :tree
    get "/count/:device_id", UploadController, :count
    get "/rooms", UploadController, :rooms
    get "/tts", TtsController, :index
  end

  scope "/api", VoiceBbsWeb do
    pipe_through :api_auth

    post "/upload", UploadController, :create
    post "/migrate", UploadController, :migrate
    post "/create-room", UploadController, :new
    post "/new", UploadController, :new
    delete "/posts/:id", UploadController, :delete
  end
end
