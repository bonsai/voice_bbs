defmodule Mix.Tasks.Voice do
  use Mix.Task

  @shortdoc "Voice BBS management CLI"

  def run(["room", "create" | args]) do
    source = Enum.find_value(args, "board", fn
      "--source=" <> s -> s
      _ -> nil
    end)

    Application.ensure_all_started(:voice_bbs)
    IO.write("Creating room... ")
    {_dur, {status, result}} = :timer.tc(fn -> VoiceBbs.Posts.add_post("cli-" <> random_hex(8), minimal_png(), 1.0, source, Ecto.UUID.generate()) end)
    case status do
      :ok -> IO.puts("OK #{result.id} (#{result.room_id})")
      {:error, reason} -> IO.puts("FAIL #{reason}")
    end
  end

  def run(["room", "list"]) do
    Application.ensure_all_started(:voice_bbs)
    posts = VoiceBbs.Posts.list_posts()
    grouped = Enum.group_by(posts, & &1.room_id)

    IO.puts("┌─ Rooms ──────────────")
    for {room_id, items} <- grouped, room_id != nil do
      IO.puts("│ #{String.slice(room_id, 0..7)}.. (#{length(items)} posts)")
    end
    others = Map.get(grouped, nil, [])
    if others != [] do
      IO.puts("│ (no room) (#{length(others)} posts)")
    end
    IO.puts("└─ #{map_size(grouped)} groups, #{length(posts)} total")
  end

  def run(["stats"]) do
    Application.ensure_all_started(:voice_bbs)
    posts = VoiceBbs.Posts.list_posts()
    with_room = Enum.count(posts, &(&1.room_id != nil))
    by_source = Enum.frequencies_by(posts, &(&1.source || "board"))

    IO.puts("Total posts: #{length(posts)}")
    IO.puts("With room:   #{with_room}")
    IO.puts("No room:     #{length(posts) - with_room}")
    IO.puts("By source:")
    for {src, n} <- Enum.sort_by(by_source, &elem(&1, 1), :desc) do
      IO.puts("  #{src}: #{n}")
    end
  end

  def run(_), do: IO.puts("Usage: mix voice room create|list | mix voice stats")

  defp random_hex(n), do: :crypto.strong_rand_bytes(n) |> Base.encode16(case: :lower)

  defp minimal_png do
    <<137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82,
      0, 0, 0, 1, 0, 0, 0, 1, 8, 2, 0, 0, 0, 144, 119, 83, 222,
      0, 0, 0, 12, 73, 68, 65, 84, 8, 215, 99, 248, 207, 0, 0, 0,
      3, 0, 1, 55, 46, 48, 42, 0, 0, 0, 0, 73, 69, 78, 68, 174,
      66, 96, 130>>
  end
end
