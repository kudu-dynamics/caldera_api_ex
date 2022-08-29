defmodule CalderaApi.Plugs.S3Unreachable do
  @moduledoc """
  Format an error message when the upstream S3 service is unavailable.

  This plug halts as it results in an error condition.
  """

  use Plug.Builder
  import CalderaApi.Plugs.Json, only: [json: 2]

  plug(:s3_unreachable)

  @spec s3_unreachable(Plug.Conn.t(), Plug.opts()) :: Plug.Conn.t()
  def s3_unreachable(conn, _opts) do
    endpoint = System.get_env("AWS_ENDPOINT_URL")

    conn
    |> json(
      status: 504,
      payload: %{error: "upstream S3 endpoint is unreachable: #{endpoint}"}
    )
    |> send_resp
    |> halt
  end
end
