# --------------------------------------------------------------------------- #

FROM elixir:1.10.3-alpine AS build

COPY lib /app/lib
COPY mix.exs /app/
COPY mix.lock /app/

ENV MIX_ENV=prod

WORKDIR /app/

RUN \
  apk add --no-cache --update git && \
  mix local.hex --force && \
  mix local.rebar --force && \
  mix deps.get && \
  mix release

# --------------------------------------------------------------------------- #

FROM elixir:1.10.3-alpine AS RELEASE

RUN \
  adduser -D app

WORKDIR /home/app

COPY --from=build /app/_build/prod/rel/caldera_api .
COPY entrypoint.sh ./

RUN \
  chown -R app: ./ && \
  chmod +x entrypoint.sh

USER app

ENV MIX_ENV=prod

ENTRYPOINT ["./entrypoint.sh"]

# --------------------------------------------------------------------------- #
