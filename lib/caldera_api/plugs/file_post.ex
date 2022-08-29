defmodule CalderaApi.Plugs.FilePost do
  @moduledoc """
  Given a sha256 parameter, validate it and check if it exists in upstream
  S3-powered storage.

  Validate an optionally-specified list of string parameter keys and set a
  payload to be sent to the `nats-to-nomad` service for processing.

  ## Plug Assigns

    * `:sha256` - the sha256 value of the target file

  ## Plug Options

    * `:bucket` - Sonic bucket to search, required
    * `:collection` - Sonic collection to search, required
    * `:job_name` - name of the Nomad job name to dispatch
    * `:meta_params` - list of allowable meta parameters, default []
    * `:only_once` - only process if no results exist, default false
    * `:s3_input` - target S3 uri (bucket/object)
    * `:subject` - the NATS subject to query
    * `:term` - key to look up value in assigns to use as the ingest term
    * `:timeout` - the NATS request timeout duration in milliseconds, default 30_000
  """

  use Plug.Builder

  alias CalderaApi.Plugs
  import Plugs.Json, only: [json: 2]

  plug(Plugs.ValidateSha256)
  plug(:validate_params, builder_opts())
  plug(Plugs.S3CheckSha256)
  plug(:only_once, builder_opts())
  plug(:nats_request, builder_opts())
  plug(:sonic_push, builder_opts())
  plug(:respond)

  @spec validate_params(Plug.Conn.t(), Plug.opts()) :: Plug.Conn.t()
  def validate_params(%Plug.Conn{assigns: %{sha256: sha256}, params: params} = conn, opts) do
    job_name = opts[:job_name]
    meta_params = Keyword.get(opts, :meta_params, [])
    s3_input = Keyword.get(opts, :s3_input, "data-bysha256/#{sha256}")

    meta =
      params
      # Drop empty parameters.
      |> Enum.reject(fn {_, v} -> is_nil(v) end)
      # Drop unrecognized parameters.
      |> Enum.filter(fn {k, _} -> Enum.member?(meta_params, k) end)
      |> Map.new()
      |> Map.put(:s3_input, s3_input)

    assign(conn, :payload, %{
      job_name: job_name,
      meta: meta
    })
  end

  @spec only_once(Plug.Conn.t(), Plug.opts()) :: Plug.Conn.t()
  def only_once(%Plug.Conn{assigns: %{sha256: _sha256}} = conn, opts) do
    if Keyword.get(opts, :only_once, false) do
      conn =
        Plugs.SonicQuery.call(
          conn,
          Plugs.SonicQuery.init(Keyword.merge([term: :sha256], opts))
        )

      case {conn.state, conn.assigns[:sonic_results]} do
        {:sent, _} ->
          conn

        # We haven't indexed any possible report locations for this file.
        {_, nil} ->
          conn

        {_, []} ->
          conn

        # Results already exist.
        {_, [_first | _]} ->
          conn
          |> send_resp(200, "")
          |> halt()
      end
    else
      conn
    end
  end

  @spec nats_request(Plug.Conn.t(), Plug.opts()) :: Plug.Conn.t()
  def nats_request(conn, opts) do
    conn = Plugs.NatsRequest.call(conn, Plugs.NatsRequest.init(opts))

    # Set the response payload to be the NATS response.
    if conn.state == :sent do
      conn
    else
      conn
      |> json(payload: conn.assigns.response)
    end
  end

  @spec sonic_push(Plug.Conn.t(), Plug.opts()) :: Plug.Conn.t()
  def sonic_push(conn, opts) do
    Plugs.SonicPush.call(
      conn,
      Plugs.SonicPush.init(Keyword.merge([term: :s3_output], opts))
    )
  end

  @spec respond(Plug.Conn.t(), Plug.opts()) :: Plug.Conn.t()
  def respond(conn, _opts) do
    conn
    |> put_status(201)
    |> send_resp()
  end
end
