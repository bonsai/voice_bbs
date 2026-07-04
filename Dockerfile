FROM hexpm/elixir:1.17.3-erlang-27.2.4-debian-bookworm-20250224

WORKDIR /app

RUN apt-get update -qq && apt-get install -y -qq git ca-certificates && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV=prod

COPY mix.exs mix.lock ./
RUN mix deps.get --only prod

COPY config/ config/
COPY lib/ lib/
COPY priv/ priv/
COPY assets/ assets/

RUN mix assets.setup
RUN mix assets.deploy
RUN mix compile

ENV PHX_SERVER=true
ENV PORT=4000

EXPOSE 4000

CMD ["sh", "-c", "for i in 1 2 3 4 5; do mix ecto.migrate && break; echo 'DB not ready, retrying...'; sleep 5; done; mix phx.server"]
