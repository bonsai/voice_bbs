defmodule VoiceBbsWeb.Plugs.Auth do
  import Plug.Conn
  import Phoenix.Controller

  @token System.get_env("BUBBLE_AUTH_TOKEN", "bubble2026")

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        if token == @token do
          conn
        else
          conn |> put_status(:unauthorized) |> json(%{error: "invalid token"}) |> halt()
        end

      _ ->
        case conn.params do
          %{"token" => token} ->
            if token == @token do
              conn
            else
              conn |> put_status(:unauthorized) |> json(%{error: "invalid token"}) |> halt()
            end

          _ ->
            conn |> put_status(:unauthorized) |> json(%{error: "missing authorization"}) |> halt()
        end
    end
  end
end
