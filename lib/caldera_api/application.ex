defmodule CalderaApi.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    Logger.configure(level: :info, utc_log: true)

    # Load configuration from environment variables.
    configure_s3()

    # Specify the supervision tree children.
    children = [
      Plug.Cowboy.child_spec(
        scheme: :http,
        plug: CalderaApi.Endpoint,
        options: [port: 4001]
      ),
      %{
        id: :gnat_conn,
        start: {
          Backends.NatsPool,
          :start_link,
          []
        },
        type: :supervisor
      },
      %{
        id: :redis_conn,
        start: {
          Backends.RedisPool,
          :start_link,
          []
        },
        type: :supervisor
      },
      %{
        id: :sonix_ingest_conn,
        start: {
          Backends.SonicPool,
          :start_link,
          [mode: "ingest"]
        },
        type: :supervisor
      },
      %{
        id: :sonix_search_conn,
        start: {
          Backends.SonicPool,
          :start_link,
          [mode: "search"]
        },
        type: :supervisor
      }
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CalderaApi.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def configure_s3 do
    # Point the S3 library at MinIO
    [scheme, host, port] =
      System.get_env("AWS_ENDPOINT_URL", "http://localhost:9000")
      |> String.split(":")
      |> Enum.map(&String.replace(&1, "//", ""))
      |> case do
        [scheme = "http", host] -> [scheme, host, "80"]
        [scheme = "https", host] -> [scheme, host, "443"]
        [scheme, host, port] -> [scheme, host, port]
      end

    Application.put_env(
      :ex_aws,
      :s3,
      ExAws.Config.new(:s3,
        host: host,
        port: port,
        scheme: scheme <> "://"
      )
    )
  end
end
