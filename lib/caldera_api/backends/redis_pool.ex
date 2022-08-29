defmodule Backends.RedisPool do
  @moduledoc false

  use Supervisor

  defp pool_name do
    :redis_pool
  end

  def start_link do
    Supervisor.start_link(__MODULE__, [])
  end

  @impl true
  def init(_opts) do
    pool_options = [
      {:name, {:local, pool_name()}},
      {:worker_module, Redix},
      {:size, 8},
      {:max_overflow, 32}
    ]

    children = [
      :poolboy.child_spec(pool_name(), pool_options, configure())
    ]

    opts = [strategy: :one_for_one]
    Supervisor.init(children, opts)
  end

  defp configure do
    # Load configuration variables from the environment for connecting to Redis.
    redis_host = System.get_env("REDIS_HOST", "localhost")
    {redis_port, _} = Integer.parse(System.get_env("REDIS_PORT", "6379"))
    redis_db = System.get_env("REDIS_DB", "0")

    [
      database: redis_db,
      host: redis_host,
      port: redis_port
    ]
  end

  # Public API

  @spec get_all(list(term())) :: {:timeout, :full} | {:ok, term()}
  def get_all(keys) do
    pool = pool_name()

    case :poolboy.checkout(pool, false) do
      :full ->
        {:timeout, :full}

      pid ->
        try do
          keys
          |> Enum.map(fn key ->
            with {:ok, value} <- Redix.command(pid, ["GET", key]) do
              value
            end
          end)
          |> (fn x -> {:ok, x} end).()
        after
          :poolboy.checkin(pool, pid)
        end
    end
  end
end
