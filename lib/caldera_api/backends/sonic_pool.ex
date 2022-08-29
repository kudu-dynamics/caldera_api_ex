defmodule Backends.SonicPool do
  @moduledoc false

  use Supervisor

  defp pool_name(mode) do
    case mode do
      "ingest" -> :sonic_ingest_pool
      "search" -> :sonic_search_pool
    end
  end

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, [opts])
  end

  @impl true
  def init(opts) do
    mode = Keyword.get(opts, :mode)

    pool_options = [
      {:name, {:local, pool_name(mode)}},
      {:worker_module, CalderaApi.SonixSupervisor},
      {:size, 0},
      {:max_overflow, 20}
    ]

    children = [
      :poolboy.child_spec(
        pool_name(mode),
        pool_options,
        configure(mode)
      )
    ]

    opts = [strategy: :one_for_one]
    Supervisor.init(children, opts)
  end

  defp configure(mode) do
    # Load configuration variables from the environment for connecting to Sonic.
    sonic_host = System.get_env("SONIC_HOST", "localhost")
    sonic_password = System.get_env("SONIC_PASSWORD", "SecretPassword")
    {sonic_port, _} = Integer.parse(System.get_env("SONIC_PORT", "1491"))

    [
      host: sonic_host,
      mode: mode,
      password: sonic_password,
      port: sonic_port
    ]
  end

  # Public API

  @spec query(term(), term(), term()) :: {:timeout, :full} | {:ok, term()} | {:error, term()}
  def query(collection, bucket, term) do
    pool = pool_name("search")

    case :poolboy.checkout(pool, false) do
      :full ->
        {:timeout, :full}

      pid ->
        try do
          pid
          |> GenServer.call({:query, collection, bucket, term})
        after
          :poolboy.checkin(pool, pid)
        end
    end
  end

  @spec push(term(), term(), term(), term()) :: {:timeout, :full} | :ok | {:error, term()}
  def push(collection, bucket, term, value) do
    pool = pool_name("ingest")

    case :poolboy.checkout(pool, false) do
      :full ->
        {:timeout, :full}

      pid ->
        try do
          pid
          |> GenServer.call({:push, collection, bucket, term, value})
        after
          :poolboy.checkin(pool, pid)
        end
    end
  end
end
