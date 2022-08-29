defmodule CalderaApi.Plugs.RetryHeader do
  @moduledoc """
  If a connection has a safely retryable status code, attach a response header
  indicating a reasonable amount of time to wait before attempting to reach the API again.
  """

  use Plug.Builder

  @retries [429, 503, 504]

  plug(:retry_header)

  @spec retry_header(Plug.Conn.t(), Plug.opts()) :: Plug.Conn.t()
  def retry_header(%Plug.Conn{status: status} = conn, _opts)
      when status in @retries do
    # Defy thundering herd issues with some jitter.
    jitter = Kernel.round(10 + :rand.uniform() * 20)
    put_resp_header(conn, "Retry-After", "#{jitter}")
  end

  def retry_header(conn, _opts), do: conn
end
