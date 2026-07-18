defmodule VoiceBbsWeb.TtsController do
  use VoiceBbsWeb, :controller

  def index(conn, %{"text" => text}) do
    text = String.trim(text)

    cond do
      text == "" ->
        json(conn, %{ok: false, error: "empty text"})

      String.length(text) > 200 ->
        json(conn, %{ok: false, error: "text too long (max 200 chars)"})

      true ->
        case generate_tts(text) do
          {:ok, audio_url} ->
            json(conn, %{ok: true, text: text, audio_url: audio_url})

          {:error, reason} ->
            json(conn, %{ok: false, error: reason})
        end
    end
  end

  def index(conn, _params) do
    json(conn, %{ok: false, error: "missing text param"})
  end

  defp generate_tts(text) do
    try do
      # Use espeak via command line for Japanese TTS
      tmp_wav = "/tmp/tts_#{:erlang.unique_integer([:positive])}.wav"
      tmp_png = "/tmp/tts_#{:erlang.unique_integer([:positive])}.png"

      case System.cmd("espeak-ng", ["-v", "ja", "-w", tmp_wav, text], stderr_to_stdout: true) do
        {_, 0} ->
          case encode_wav_to_png(tmp_wav, tmp_png) do
            {:ok, png_data} ->
              upload_to_gcs(png_data, tmp_png)

            err ->
              err
          end

        {output, _} ->
          # Fallback: try espeak without -ng
          case System.cmd("espeak", ["-v", "ja", "-w", tmp_wav, text], stderr_to_stdout: true) do
            {_, 0} ->
              case encode_wav_to_png(tmp_wav, tmp_png) do
                {:ok, png_data} ->
                  upload_to_gcs(png_data, tmp_png)

                err ->
                  err
              end

            _ ->
              {:error, "tts engine not available: #{output}"}
          end
      end
    after
      File.rm("/tmp/tts_*.wav")
      File.rm("/tmp/tts_*.png")
    end
  end

  defp encode_wav_to_png(wav_path, png_path) do
    # Simple WAV to PNG encoding (same as audio_recorder.js but in Elixir)
    case File.read(wav_path) do
      {:ok, wav_data} ->
        # Store raw WAV bytes as PNG pixels
        pixel_count = div(byte_size(wav_data) + 2, 3) + 1
        width = min(pixel_count, 1000)
        height = max(div(pixel_count, width), 1)

        png_data = encode_audio_to_png(wav_data, width, height)
        {:ok, png_data}

      err ->
        err
    end
  end

  defp encode_audio_to_png(audio_data, width, height) do
    # Create minimal PNG with audio data embedded in pixels
    png_header = <<137, 80, 78, 71, 13, 10, 26, 10>>

    # IHDR
    ihdr_data = <<width::32, height::32, 8::8, 2::8, 0::8, 0::8, 0::8>>
    ihdr_crc = :erlang.crc32(<<"IHDR", ihdr_data::binary>>)
    ihdr = <<byte_size(ihdr_data)::32, "IHDR", ihdr_data::binary, ihdr_crc::32>>

    # IDAT - simple uncompressed deflate
    raw_data = for <<byte <- audio_data>>, into: <<>> do
      <<0::8, byte::8>>
    end

    zlib = :zlib.open()
    :zlib.deflateInit(zlib)
    compressed = :zlib.deflate(zlib, raw_data, :finish)
    :zlib.deflateEnd(zlib)
    :zlib.close(zlib)

    idat_crc = :erlang.crc32(<<"IDAT", compressed::binary>>)
    idat = <<byte_size(compressed)::32, "IDAT", compressed::binary, idat_crc::32>>

    # IEND
    iend_crc = :erlang.crc32(<<"IEND">>)
    iend = <<0::32, "IEND", iend_crc::32>>

    png_header <> ihdr <> idat <> iend
  end

  defp upload_to_gcs(png_data, tmp_path) do
    bucket = "bubblevoice-uploads"
    filename = "tts/#{System.system_time(:second)}_#{:erlang.unique_integer([:positive])}.png"
    url = "https://storage.googleapis.com/#{bucket}/#{filename}"

    case Goth.Token.for_scope("https://www.googleapis.com/auth/cloud-platform") do
      {:ok, token} ->
        upload_url = "https://storage.googleapis.com/upload/storage/v1/b/#{bucket}/o?uploadType=media&name=#{filename}"

        case Req.post(upload_url, body: png_data, headers: [{"content-type", "image/png"}, {"authorization", "Bearer #{token.token}"}]) do
          {:ok, %{status: status}} when status in 200..299 ->
            File.rm(tmp_path)
            {:ok, url}

          {:ok, resp} ->
            {:error, "upload failed: #{inspect(resp.status)}"}

          {:error, err} ->
            {:error, "upload error: #{inspect(err)}"}
        end

      {:error, err} ->
        {:error, "auth error: #{inspect(err)}"}
    end
  end
end
