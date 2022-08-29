defmodule Backends.NatsPool do
  @moduledoc false

  use Supervisor

  defp pool_name do
    :nats_pool
  end

  def start_link do
    Supervisor.start_link(__MODULE__, [])
  end

  # DEV: Suppress dialyzer for init here as Gnat takes in a Map rather than a
  #      keyword list as :poolboy.child_spec is expecting.
  @dialyzer {:nowarn_function, init: 1}
  @impl true
  def init(_opts) do
    pool_options = [
      {:name, {:local, pool_name()}},
      {:worker_module, Gnat},
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
    # Load configuration variables from the environment for connecting to NATS.
    nats_host = System.get_env("NATS_HOST", "localhost")
    {nats_port, _} = Integer.parse(System.get_env("NATS_PORT", "4222"))

    %{
      host: nats_host,
      port: nats_port
    }
  end

  # Public API

  @spec request(term(), term(), keyword()) ::
          {:timeout, :full} | {:error, :timeout} | {:ok, term()}
  def request(subject, payload, opts) do
    pool = pool_name()
    timeout = Keyword.get(opts, :receive_timeout, 30_000)

    case :poolboy.checkout(pool, false) do
      :full ->
        {:timeout, :full}

      pid ->
        try do
          pid
          |> Gnat.request(subject, payload, receive_timeout: timeout)
        after
          :poolboy.checkin(pool, pid)
        end
    end
  end
end
