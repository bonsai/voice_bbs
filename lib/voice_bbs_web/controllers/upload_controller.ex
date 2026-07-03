defmodule VoiceBbsWeb.UploadController do
  use VoiceBbsWeb, :controller

  def create(conn, %{"image_base64" => b64}) do
    png_data = Base.decode64!(b64)
    post = VoiceBbs.Posts.add_post(png_data)

    json(conn, %{ok: true, id: post.id, url: post.url})
  end
end
