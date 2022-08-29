defmodule CalderaApi.Endpoint do
  @moduledoc """
  A Plug responsible for logging request info, parsing request body's as JSON,
  matching routes, and dispatching responses.
  """

  require Logger

  use Plug.Router

  # DEV: :match needs to come before :dispatch
  plug(:match)

  plug(Plug.Parsers,
    parsers: [:json, :urlencoded],
    json_decoder: Jason
  )

  plug(:dispatch)

  # A simple route to test that the server is up
  # Note, all routes must return a connection as per the Plug spec.
  get "/ping" do
    conn
    |> send_resp(200, "pong!")
    |> halt
  end

  # XXX: Legacy endpoint that needs to be deprecated.
  get("/hash/:sha256", to: CalderaApi.Symboliker.Query)
  post("/hash/:sha256", to: CalderaApi.Symboliker.Request)

  get("/file/:sha256/pharos_fn2hash", to: CalderaApi.PharosFn2Hash.Query)
  post("/file/:sha256/pharos_fn2hash", to: CalderaApi.PharosFn2Hash.Request)

  put(
    "/file/:sha256/pharos_fn2hash",
    to: CalderaApi.PharosFn2Hash.Request,
    init_opts: [only_once: true]
  )

  get("/file/:sha256/symboliker", to: CalderaApi.Symboliker.Query)
  post("/file/:sha256/symboliker", to: CalderaApi.Symboliker.Request)

  put(
    "/file/:sha256/symboliker",
    to: CalderaApi.Symboliker.Request,
    init_opts: [only_once: true]
  )

  get("/tpx/:value", to: CalderaApi.ThreatProximity.Query)
  post("/tpx", to: CalderaApi.ThreatProximity.Query)

  post("/etl/fishbowl", to: CalderaApi.Fishbowl.Request)

  match _ do
    conn
    |> send_resp(404, "oops")
    |> halt
  end
end
