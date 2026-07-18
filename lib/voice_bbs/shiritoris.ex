defmodule VoiceBbs.Shiritoris do
  import Ecto.Query
  alias VoiceBbs.Repo
  alias VoiceBbs.Shiritori

  @doc "Get the full chain ordered by position"
  def list_chain do
    from(s in Shiritori, order_by: [asc: s.position])
    |> Repo.all()
  end

  @doc "Get the last word in the chain (latest position)"
  def last_word do
    from(s in Shiritori, order_by: [desc: s.position], limit: 1)
    |> Repo.one()
  end

  @doc "Validate and add a new word to the chain"
  def add_word(word, kana, device_id, audio_url \\ nil) do
    kana = normalize_kana(kana)
    last = last_word()

    case validate_next(last, kana) do
      :ok ->
        position = if last, do: last.position + 1, else: 0
        prev_id = if last, do: last.id, else: nil

        %Shiritori{}
        |> Shiritori.changeset(%{
          word: word,
          kana: kana,
          device_id: device_id,
          audio_url: audio_url,
          position: position,
          prev_id: prev_id
        })
        |> Repo.insert()

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "Validate next word against the last word's ending kana"
  def validate_next(nil, _kana), do: :ok

  def validate_next(last, kana) do
    last_kana = normalize_kana(last.kana)
    last_char = String.slice(last_kana, -1, 1)
    first_char = String.slice(kana, 0, 1)

    cond do
      last_char == "ん" ->
        {:error, "game_over_n"}

      last_char == "っ" ->
        if first_char == "っ" do
          :ok
        else
          {:error, "expected_tsu"}
        end

      last_char == first_char ->
        :ok

      true ->
        {:error, "mismatch", last_char, first_char}
    end
  end

  @doc "Convert a word to kana (simplified - assumes input is already kana or katakana)"
  def normalize_kana(kana) do
    kana
    |> String.trim()
    |> String.downcase()
    |> katakana_to_hiragana()
  end

  @doc "Katakana → Hiragana conversion"
  def katakana_to_hiragana(str) do
    str
    |> String.to_charlist()
    |> Enum.map(fn
      c when c in 0x30A1..0x30F6 -> c - 0x60
      c -> c
    end)
    |> List.to_string()
  end

  @doc "Get the last kana of a word"
  def last_kana(kana) do
    kana = normalize_kana(kana)
    String.slice(kana, -1, 1)
  end

  @doc "Get the first kana of a word"
  def first_kana(kana) do
    kana = normalize_kana(kana)
    String.slice(kana, 0, 1)
  end

  @doc "Reset the chain (start over)"
  def reset_chain do
    from(s in Shiritori) |> Repo.delete_all()
  end
end
