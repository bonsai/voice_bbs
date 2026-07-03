defmodule VoiceBbsWeb.UploadController do
  use VoiceBbsWeb, :controller

  def create(conn, %{"image_base64" => b64, "duration" => duration}) do
    png_data = Base.decode64!(b64)
    dur = parse_duration(duration)
    post = VoiceBbs.Posts.add_post(png_data, dur)

    json(conn, %{ok: true, id: post.id, url: post.url, duration: post.duration})
  end

  defp parse_duration(d) when is_number(d), do: max(d, 0.1)
  defp parse_duration(_d), do: 0.1
end
