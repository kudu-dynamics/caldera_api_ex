defmodule CalderaApi.Plugs.RedirectToUrl do
  @moduledoc """
  Redirect a connection that has been specially assigned a redirect URL
  previously in the pipeline.

  ## Plug Options

    * `:status` - sets the connection status, defaults to `307`
  """

  use Plug.Builder

  plug(:redirect_to_url, builder_opts())

  @spec redirect_to_url(Plug.Conn.t(), Plug.opts()) :: Plug.Conn.t()
  def redirect_to_url(%Plug.Conn{assigns: %{url: url}} = conn, opts) do
    status = Keyword.get(opts, :status, 307)

    conn
    |> put_resp_header("location", url)
    |> send_resp(status, "")
  end
end
