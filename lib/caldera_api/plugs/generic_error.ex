defmodule CalderaApi.Plugs.GenericError do
  @moduledoc """
  Assign and log a generic 500 internal server error in unexpected cases.

  ## Plug Options

    * `:error` - error object to log
    * `:source` - string describing the location of the error, usually derived from `__MODULE__`

  """

  use Plug.Builder
  import CalderaApi.Plugs.Json, only: [json: 2]
  require Logger

  plug(:generic_error, builder_opts())

  @spec generic_error(Plug.Conn.t(), Plug.opts()) :: Plug.Conn.t()
  def generic_error(conn, opts) do
    err = opts[:error]
    source = Keyword.get(opts, :source, __MODULE__)

    Logger.error("#{source} #{inspect(err)}")

    conn
    |> json(
      status: 500,
      payload: %{error: "unexpected internal server error"}
    )
    |> send_resp
    |> halt
  end
end
