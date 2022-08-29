defmodule CalderaApi.PharosFn2Hash.Request do
  @moduledoc false

  use CalderaApi.PharosFn2Hash.Constants
  use Plug.Builder

  alias CalderaApi.Plugs

  plug(Plugs.AssignParam, param: "sha256")
  plug(:file_post, builder_opts())

  @spec file_post(Plug.Conn.t(), Plug.opts()) :: Plug.Conn.t()
  def file_post(conn, opts) do
    Plugs.FilePost.call(
      conn,
      Plugs.FilePost.init(
        Keyword.merge(
          [
            bucket: @sonic_bucket,
            collection: @sonic_collection,
            job_name: @nomad_job,
            meta_params: [
              "functime",
              "timeout"
            ],
            subject: @nats_subject
          ],
          opts
        )
      )
    )
  end
end
