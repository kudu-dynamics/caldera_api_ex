defmodule CalderaApi.Plugs.S3CheckSha256 do
  @moduledoc """
  Check that the input sha256 is available in a configured S3 endpoint.
  """

  use Plug.Builder

  require Logger

  alias CalderaApi.Plugs
  import Plugs.Json, only: [json: 2]
  import Plugs.S3Unreachable, only: [s3_unreachable: 2]

  plug(:s3_check_sha256)

  @spec s3_check_sha256(Plug.Conn.t(), Plug.opts()) :: Plug.Conn.t()
  def s3_check_sha256(%Plug.Conn{assigns: %{sha256: sha256}} = conn, opts) do
    reply =
      ExAws.S3.head_object("data-bysha256", sha256)
      |> ExAws.request()

    case reply do
      # Confirmed existence of the file.
      {:ok, _response} ->
        conn

      # File does not currently exist at upstream S3 endpoint.
      {:error, {:http_error, 404, meta}} ->
        headers = Map.get(meta, :headers, [])
        is_s3? = Enum.any?(headers, fn {k, _} -> k == "Server" end)

        if is_s3? do
          # Check common S3 headers to ensure the endpoint is returning a true
          # resource 404 response.
          conn
          |> json(
            status: 404,
            payload: %{error: "sha256 unavailable for processing"}
          )
          |> send_resp()
          |> halt()
        else
          # A 404 returned otherwise could be due to a variety of reasons such
          # as a reverse proxy misconfiguration or service outage.
          s3_unreachable(conn, opts)
        end

      # Cannot resolve S3 endpoint.
      {:error, :nxdomain} ->
        s3_unreachable(conn, opts)

      # Some other error occurred.
      {:error, err} ->
        Logger.error("#{inspect(err)}")

        conn
        |> json(
          status: 503,
          payload: %{error: "sha256 unavailable for processing"}
        )
        |> send_resp()
        |> halt()
    end
  end
end
