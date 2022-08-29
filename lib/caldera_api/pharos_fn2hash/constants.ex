defmodule CalderaApi.PharosFn2Hash.Constants do
  @moduledoc """
  Constants shared by PharosFn2Hash plugs.
  """

  defmacro __using__(_) do
    quote do
      @nats_subject "analytic.pharos_fn2hash"

      @nomad_job "analytic/i0xen/pharos_fn2hash"

      # XXX add sonic_collection
      @sonic_collection "<sonic_collection?"
      @sonic_bucket "pharos_fn2hash"

      _ = :sha256
    end
  end
end
