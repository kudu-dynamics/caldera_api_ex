defmodule CalderaApi.Plugs.AssignParam do
  @moduledoc """
  Given a connection parameter, map it to the conection assignments.

  For safety reasons, the provided param value must be an existing atom.

  ## Plug Options

    * `:param` - key of the parameter to assign

  ## Examples

  ```
  conn = AssignParam.call(conn, param: "sha256")
  assert Map.has_key?(conn.assigns, "sha256")
  ```
  """

  use Plug.Builder

  plug(:assign_param, builder_opts())

  @spec assign_param(Plug.Conn.t(), Plug.opts()) :: Plug.Conn.t()
  def assign_param(conn, opts) do
    param = opts[:param]
    assign(conn, String.to_existing_atom(param), conn.params[param])
  end
end
