defmodule CalderaApi.SonixSupervisor do
  @moduledoc """
  A process that supervises a Sonix connection.

  Automatically reconnects in case of failure.
  Does this by overriding the reconnect behaviour of the Sonix library.

  ```
  sonix_supervisor_settings = %{
    backoff_period: 4_000,  # number of milliseconds to wait between consecutive
                            # reconnect attempts (default: 2_000)
    host: "127.0.0.1",      # (default value) sonic server host
    mode: "ingest"          # (ingest/search) sonic client mode
    port: 1491,             # (default value) sonic server port
  }
  ```

  Derived from https://github.com/nats-io/nats.ex/blob/master/lib/gnat/connection_supervisor.ex
  """

  require Logger

  use GenServer

  @jitter_pct 0.25
  @jitter_step 500

  @spec start_link(map(), keyword()) :: GenServer.on_start()
  def start_link(settings, options \\ []) do
    GenServer.start_link(__MODULE__, settings, options)
  end

  @impl GenServer
  def init(settings) do
    Process.flag(:trap_exit, true)

    send(self(), :connect)

    # Connection variables.
    settings = Map.new(settings)
    backoff_period = Map.get(settings, :backoff_period, 2_000)
    host = Map.get(settings, :host, "127.0.0.1")
    mode = Map.get(settings, :mode)
    password = Map.get(settings, :password)
    {port, _} = Map.get(settings, :port, "1491") |> to_string() |> Integer.parse()

    state = %{
      backoff_cap: 10,
      backoff_count: 0,
      backoff_period: backoff_period,
      connection_pid: nil,
      host: host,
      mode: mode,
      password: password,
      port: port,
      ready: false
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_info(:connect, state) do
    Logger.debug(
      "establishing supervised Sonix connection: " <>
        "#{state.host}:#{state.port}"
    )

    case Sonix.init(state.host, state.port) do
      {:ok, pid} ->
        case Sonix.start(pid, state.mode, state.password) do
          {:ok, _pid} ->
            Logger.debug("connected to Sonic server: #{state.mode}")
            {:noreply, state_connected(state, pid)}

          {:error, "ENDED authentication_failed"} ->
            {:stop, "Sonix authentication failure: check Sonic password", state}

          {:error, err} ->
            Logger.error(
              "unexpected error while supervising Sonix " <>
                "connection: #{inspect(err)}"
            )

            {:noreply, reconnect(state)}
        end

      {:error, err} ->
        Logger.error(
          "failed to establish supervised Sonix connection " <>
            "[#{state.backoff_count}]: #{inspect(err)}"
        )

        {:noreply, reconnect(state)}
    end
  end

  def handle_info({:EXIT, _pid, _reason}, state) do
    {:noreply, %{state | ready: false}}
  end

  def handle_info(msg, state) do
    Logger.error("#{__MODULE__} received unexpected message #{inspect(msg)}")
    {:noreply, state}
  end

  @impl GenServer
  def handle_call(
        {:query, collection, bucket, term},
        _from,
        %{connection_pid: pid, ready: true} = state
      ) do
    case Sonix.query(pid, collection, bucket, term) do
      {:ok, results} -> {:reply, {:ok, results}, state}
      msg -> handle_error(msg, state)
    end
  end

  @impl GenServer
  def handle_call({:query, _, _, _}, _from, state) do
    {:reply, {:error, :notready}, state}
  end

  @impl GenServer
  def handle_call(
        {:push, collection, bucket, term, value},
        _from,
        %{connection_pid: pid, ready: true} = state
      ) do
    case Sonix.push(pid, collection, bucket, term, value) do
      :ok -> {:reply, :ok, state}
      msg -> handle_error(msg, state)
    end
  end

  @impl GenServer
  def handle_call({:push, _, _, _, _}, _from, state) do
    {:reply, {:error, :notready}, state}
  end

  # XXX: verify if both of the following disconnect cases are actually possible

  defp handle_error({:error, {:error, :closed}}, state) do
    # Connection to Sonic was closed.
    {:reply, {:error, :connection_closed}, reconnect(state)}
  end

  defp handle_error({:error, :closed}, state) do
    # Connection to Sonic was closed.
    {:reply, {:error, :connection_closed}, reconnect(state)}
  end

  # XXX: verify if these are errors that we can safely just reconnect for

  defp handle_error({:error, err}, state) do
    Logger.warn("SonixSupervisor API error: #{inspect(err)}")
    {:reply, {:error, err}, reconnect(state)}
  end

  defp jitter(backoff_cap, backoff_count) do
    # Return some number of milliseconds.
    jitter_max = min(backoff_cap, backoff_count) * @jitter_step
    jitter_pct = :rand.uniform_real() * @jitter_pct + (1 - @jitter_pct)
    Kernel.round(jitter_max * jitter_pct)
  end

  defp reconnect(state) do
    if state.connection_pid != nil and Process.alive?(state.connection_pid) do
      # Sonix initialized a named GenServer that is trying its own
      # reconnect logic.
      Process.exit(state.connection_pid, :kill)
    end

    # Add a potential jitter step for each reconnect attempt up to a capped
    # maximum jitter delay.
    backoff_period = jitter(state.backoff_cap, state.backoff_count)
    backoff_millis = Kernel.round(backoff_period)
    Process.send_after(self(), :connect, backoff_millis)

    state_retry(state)
  end

  defp state_connected(state, pid) do
    %{state | backoff_count: 0, connection_pid: pid, ready: true}
  end

  defp state_retry(state) do
    %{state | backoff_count: state.backoff_count + 1, connection_pid: nil, ready: false}
  end
end
