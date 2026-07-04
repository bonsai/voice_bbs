defmodule VoiceBbsWeb.UploadController do
  use VoiceBbsWeb, :controller

  def create(conn, %{"image_base64" => b64, "duration" => duration, "device_id" => device_id}) do
    png_data = Base.decode64!(b64)
    dur = parse_duration(duration)

    case VoiceBbs.Posts.add_post(device_id, png_data, dur) do
      {:ok, post} ->
        remaining = VoiceBbs.Posts.max_per_device() - VoiceBbs.Posts.count_by_device(device_id)

        json(conn, %{
          ok: true,
          id: post.id,
          url: post.url,
          duration: post.duration,
          remaining: remaining
        })

      {:error, :limit_reached} ->
        json(conn, %{ok: false, error: "limit_reached", message: "Maximum 4 posts per device"})
    end
  end

  def create(conn, _params) do
    json(conn, %{ok: false, error: "missing_params"})
  end

  def count(conn, %{"device_id" => device_id}) do
    count = VoiceBbs.Posts.count_by_device(device_id)

    json(conn, %{ok: true, count: count, remaining: VoiceBbs.Posts.max_per_device() - count})
  end

  def index(conn, _params) do
    posts = VoiceBbs.Posts.list_posts()

    json(conn, %{
      ok: true,
      posts: Enum.map(posts, fn p ->
        %{
          id: p.id,
          url: p.url,
          duration: p.duration,
          device_id: p.device_id,
          inserted_at: p.inserted_at
        }
      end)
    })
  end

  def delete(conn, %{"id" => id}) do
    VoiceBbs.Posts.delete_post(id)
    json(conn, %{ok: true})
  end

  defp parse_duration(d) when is_number(d), do: max(d, 0.1)
  defp parse_duration(_d), do: 0.1
end
