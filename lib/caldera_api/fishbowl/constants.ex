defmodule CalderaApi.Fishbowl.Constants do
  @moduledoc """
  Constants shared by Fishbowl plugs.
  """

  defmacro __using__(_) do
    quote do
      @nats_subject "glue.nats-to-nomad"

      @nomad_job "etl/fishbowl"
      
      # XXX add s3_bucket
      @s3_bucket "<s3_bucket>"
    end
  end
end
