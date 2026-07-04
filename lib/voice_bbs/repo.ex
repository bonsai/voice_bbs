defmodule VoiceBbs.Repo do
  use Ecto.Repo,
    otp_app: :voice_bbs,
    adapter: Ecto.Adapters.Postgres
end
