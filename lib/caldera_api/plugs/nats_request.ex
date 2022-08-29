defmodule CalderaApi.Plugs.NatsRequest do
  @moduledoc """
  Initiate a request/reply pattern over a NATS connection.

  ## Plug Assigns

    * `:payload` - the NATS request payload, required input
    * `:response` - the NATS response returned, output

  ## Plug Options

    * `:subject` - the NATS subject to query
    * `:timeout` - the NATS request timeout duration in milliseconds, default 30_000
  """

  use Plug.Builder

  alias Backends.NatsPool
  alias CalderaApi.Plugs
  import Plugs.Json, only: [json: 2]

  @default_timeout 5_000

  plug(:nats_request, builder_opts())

  @spec nats_request(Plug.Conn.t(), Plug.opts()) :: Plug.Conn.t()
  def nats_request(%Plug.Conn{assigns: %{payload: payload}} = conn, opts) do
    subject = opts[:subject]
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    reply =
      NatsPool.request(
        subject,
        payload |> Jason.encode!(),
        receive_timeout: timeout
      )

    respond(conn, opts, reply)
  end

  @spec respond(Plug.Conn.t(), Plug.opts(), term()) :: Plug.Conn.t()
  defp respond(conn, _opts, {:ok, msg}) do
    body = Jason.decode!(msg.body)
    conn = assign(conn, :response, body)

    case body do
      %{"success" => true, "s3_output" => s3_output} ->
        conn
        |> assign(:s3_output, s3_output)

      %{"success" => true, "sinks" => sinks} ->
        conn
        |> assign(:sinks, sinks)

      %{"success" => false} ->
        conn
        |> json(
          status: 503,
          payload: body
        )
        |> send_resp()
        |> halt()
    end
  end

  defp respond(
         %Plug.Conn{assigns: %{payload: %{job_name: job_name}}} = conn,
         _opts,
         {:error, :timeout}
       ) do
    # timed out waiting for a NATS reply
    conn
    |> json(status: 503, payload: %{error: "no #{job_name} workers available"})
    |> send_resp()
    |> halt()
  end

  defp respond(conn, _opts, {:timeout, _}) do
    # timed out while checking out a poolboy worker
    conn
    |> json(
      status: 504,
      payload: %{error: "temporarily unable to checkout worker from NATS pool"}
    )
    |> send_resp()
    |> halt()
  end
end
