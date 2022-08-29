defmodule CalderaApi.Plugs.SonicPush do
  @moduledoc """
  Push a value to Sonic.

  ## Plug Options

    * `:bucket` - Sonic bucket to search, required
    * `:collection` - Sonic collection to search, required
    * `:term` - key to look up value in assigns to use as the ingest term
  """

  use Plug.Builder

  alias Backends.SonicPool
  alias CalderaApi.Plugs
  import Plugs.Json, only: [json: 2]

  plug(:sonic_push, builder_opts())

  # XXX: Make this generic?
  @spec sonic_push(Plug.Conn.t(), Plug.opts()) :: Plug.Conn.t()
  def sonic_push(%Plug.Conn{assigns: %{sha256: sha256}} = conn, opts) do
    collection = opts[:collection]
    bucket = opts[:bucket]
    term = conn.assigns[opts[:term]]

    reply = SonicPool.push(collection, bucket, term, sha256)

    respond(conn, opts, reply)
  end

  @spec respond(Plug.Conn.t(), Plug.opts(), term()) :: Plug.Conn.t()
  defp respond(conn, opts, :ok) do
    conn
    |> json(opts)
  end

  defp respond(conn, _opts, {:error, _}) do
    # connection to Sonic was interrupted
    conn
    |> json(
      status: 504,
      payload: %{error: "Sonic connection was interrupted"}
    )
    |> send_resp()
    |> halt()
  end

  defp respond(conn, _opts, {:timeout, _}) do
    # timed out while checking out a poolboy worker
    conn
    |> json(
      status: 504,
      payload: %{error: "temporarily unable to checkout worker from Sonic pool"}
    )
    |> send_resp()
    |> halt()
  end
end
