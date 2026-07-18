defmodule VoiceBbsWeb.UploadController do
  use VoiceBbsWeb, :controller

  def create(conn, %{"image_base64" => b64, "duration" => duration, "device_id" => device_id} = params) do
    case Base.decode64(b64) do
      {:ok, png_data} ->
        dur = parse_duration(duration)
        source = Map.get(params, "source", "board")

        case VoiceBbs.Posts.add_post(device_id, png_data, dur, source) do
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

      :error ->
        json(conn, %{ok: false, error: "invalid_base64"})
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
          source: p.source,
          room_id: p.room_id,
          inserted_at: p.inserted_at
        }
      end)
    })
  end

  def delete(conn, %{"id" => id}) do
    VoiceBbs.Posts.delete_post(id)
    json(conn, %{ok: true})
  end

  def migrate(conn, _params) do
    Ecto.Migrator.run(VoiceBbs.Repo, :up, all: true)
    json(conn, %{ok: true, message: "migrated"})
  end

  def new(conn, params) do
    source = Map.get(params, "source", "board")
    device_id = Map.get(params, "device_id", "api-" <> Base.encode16(:crypto.strong_rand_bytes(4), case: :lower))
    room_id = Ecto.UUID.generate()

    png = <<137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82,
      0, 0, 0, 1, 0, 0, 0, 1, 8, 2, 0, 0, 0, 144, 119, 83, 222,
      0, 0, 0, 12, 73, 68, 65, 84, 8, 215, 99, 248, 207, 0, 0, 0,
      3, 0, 1, 55, 46, 48, 42, 0, 0, 0, 0, 73, 69, 78, 68, 174,
      66, 96, 130>>

    case VoiceBbs.Posts.add_post(device_id, png, 1.0, source, room_id) do
      {:ok, post} ->
        json(conn, %{ok: true, id: post.id, url: post.url, source: source, room_id: room_id})
      {:error, :limit_reached} ->
        json(conn, %{ok: false, error: "limit_reached"})
    end
  end

  def tree(conn, _params) do
    posts = VoiceBbs.Posts.list_posts()

    rooms = posts
    |> Enum.filter(&(&1.room_id != nil))
    |> Enum.group_by(& &1.room_id)
    |> Enum.map(fn {room_id, items} -> %{
      room_id: room_id,
      count: length(items),
      posts: format_posts(items)
    } end)

    by_source = Enum.group_by(posts, &(&1.source || "board"))
    sources = Enum.map(by_source, fn {src, items} -> %{
      source: src,
      count: length(items),
      posts: format_posts(items)
    } end)

    json(conn, %{
      ok: true,
      rooms: rooms,
      sources: sources
    })
  end

  defp format_posts(posts) do
    Enum.map(posts, fn p -> %{
      id: p.id,
      url: p.url,
      duration: p.duration,
      source: p.source,
      room_id: p.room_id,
      device_id: p.device_id,
      inserted_at: p.inserted_at
    } end)
  end

  defp parse_duration(d) when is_number(d), do: max(d, 0.1)
  defp parse_duration(_d), do: 0.1
end
