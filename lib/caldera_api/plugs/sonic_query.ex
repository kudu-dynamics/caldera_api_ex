defmodule CalderaApi.Plugs.SonicQuery do
  @moduledoc """
  Query Sonic for some data and assign it to the current connection.

  Various errors will result in the Plug halting.

  ## Plug Options

    * `:collection` - Sonic collection to search, required
    * `:bucket` - Sonic bucket to search, required
    * `:term` - key to look up value in assigns to use as the search term
  """

  use Plug.Builder

  alias Backends.SonicPool
  alias CalderaApi.Plugs
  import Plugs.Json, only: [json: 2]

  plug(:validate, builder_opts())
  plug(:sonic_query, builder_opts())

  @required [:collection, :bucket, :term]

  @doc """
  Notify the user if not all required options are provided.

  This signifies a misconfiguration and release of the API and requires
  a software patch to fix.
  """
  @spec validate(Plug.Conn.t(), Plug.opts()) :: Plug.Conn.t()
  def validate(conn, opts) do
    if Enum.any?(@required, fn x -> not Keyword.has_key?(opts, x) end) do
      conn
      |> json(
        status: 500,
        payload: %{
          error: "unrecoverable API error: notify administrator",
          unrecoverable: true
        }
      )
      |> halt
    else
      conn
    end
  end

  @spec sonic_query(Plug.Conn.t(), Plug.opts()) :: Plug.Conn.t()
  def sonic_query(conn, opts) do
    collection = opts[:collection]
    bucket = opts[:bucket]
    term = conn.assigns[opts[:term]]

    reply = SonicPool.query(collection, bucket, term)

    respond(conn, opts, reply)
  end

  @spec respond(Plug.Conn.t(), Plug.opts(), term()) :: Plug.Conn.t()
  defp respond(conn, _opts, {:ok, results}) do
    conn
    |> assign(:sonic_results, results)
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
