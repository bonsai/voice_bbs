FROM hexpm/elixir:1.14.5-erlang-25.3.2.16-debian-bullseye-20241223

WORKDIR /app

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

ENV MIX_ENV=prod
ENV PHX_SERVER=true
ENV PORT=4000

EXPOSE 4000

CMD ["mix", "phx.server"]
