FROM hexpm/elixir:1.17.3-erlang-27.2.4-debian-bookworm-20250224 AS builder

WORKDIR /app

ENV MIX_ENV=prod

RUN apt-get update -qq && apt-get install -y -qq git ca-certificates && apt-get clean && rm -rf /var/lib/apt/lists/*
RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
RUN mix deps.get --only prod

COPY config/ config/
COPY lib/ lib/
COPY priv/ priv/
COPY assets/ assets/

RUN mix assets.setup
RUN mix assets.deploy
RUN mix compile
RUN mix release

FROM debian:bookworm-slim AS runtime

RUN apt-get update -qq && apt-get install -y -qq libstdc++6 openssl libncurses6 ca-certificates && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /app/_build/prod/voice_bbs-*.tar.gz /app/release.tar.gz
RUN tar xzf release.tar.gz && rm release.tar.gz

ENV PHX_SERVER=true
ENV PORT=4000
ENV HOME=/app
ENV RELEASE_DISTRIBUTION=none
ENV LANG=C.UTF-8

EXPOSE 4000

CMD ["/app/bin/voice_bbs", "start"]
