defmodule CalderaApi.Plugs.Json do
  @moduledoc """
  Provide a plug that serves as an ultimate or penultimate pipeline plug.

  It sets the status, body, and sets the appropriate json content type.

  ## Plug Options

    * `:payload` - data to be JSON-encoded and set as the response body
    * `:raw` - do not re-encode the JSON string payload
    * `:status` - sets the connection status, defaults to `200`
  """

  use Plug.Builder

  plug(CalderaApi.Plugs.RetryHeader)
  plug(:json, builder_opts())

  @spec json(Plug.Conn.t(), Plug.opts()) :: Plug.Conn.t()
  def json(conn, opts) do
    conn
    |> maybe_apply(Enum.into(opts, %{}))
    |> put_resp_content_type("application/json")
  end

  defp maybe_apply(conn, %{payload: payload, raw: true, status: status}) do
    conn
    |> resp(status, payload)
  end

  defp maybe_apply(conn, %{payload: payload, status: status}) do
    conn
    |> resp(status, payload |> Jason.encode!())
  end

  defp maybe_apply(conn, %{payload: payload, raw: true}) do
    conn
    |> resp(200, payload)
  end

  defp maybe_apply(conn, %{payload: payload}) do
    conn
    |> resp(200, payload |> Jason.encode!())
  end

  defp maybe_apply(conn, %{status: status}) do
    conn
    |> put_status(status)
  end

  defp maybe_apply(conn, _opts), do: conn
end
