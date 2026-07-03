defmodule VoiceBbsWeb.HealthController do
  use VoiceBbsWeb, :controller

  def index(conn, _params) do
    json(conn, %{status: "ok"})
  end
end
