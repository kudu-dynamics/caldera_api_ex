defmodule CalderaApi.Plugs.ValidateSha256 do
  @moduledoc """
  Given a connection with a "sha256" parameter, validate it.

  In the error condition, this plug halts.

  ## Plug Assigns

    * `:sha256` - the sha256 value of the target file
  """

  use Plug.Builder

  alias CalderaApi.Plugs
  import Plugs.Json, only: [json: 2]

  plug(:validate_sha256)

  @spec validate_sha256(Plug.Conn.t(), Plug.opts()) :: Plug.Conn.t()
  def validate_sha256(%Plug.Conn{assigns: %{sha256: sha256}} = conn, _opts) do
    case String.length(sha256) do
      64 ->
        conn

      _ ->
        conn
        |> json(status: 400, payload: %{error: "invalid sha256 input value"})
        |> send_resp
        |> halt
    end
  end
end
