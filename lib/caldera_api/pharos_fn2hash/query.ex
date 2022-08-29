defmodule CalderaApi.PharosFn2Hash.Query do
  @moduledoc false

  use CalderaApi.PharosFn2Hash.Constants
  use Plug.Builder

  alias CalderaApi.Plugs
  import Plugs.Json, only: [json: 2]

  plug(Plugs.AssignParam, param: "sha256")
  plug(Plugs.ValidateSha256)

  plug(
    Plugs.SonicQuery,
    collection: @sonic_collection,
    bucket: @sonic_bucket,
    term: :sha256
  )

  plug(:result_to_s3_location)
  plug(Plugs.S3PresignedUrl, url_key: :url)
  plug(Plugs.RedirectToUrl)

  @spec result_to_s3_location(Plug.Conn.t(), Plug.opts()) :: Plug.Conn.t()
  def result_to_s3_location(%Plug.Conn{assigns: %{sonic_results: results}} = conn, _opts) do
    case results do
      # We haven't indexed any possible report locations for this file.
      [] ->
        conn
        |> json(status: 404, payload: %{error: "no pharos_fn2hash report available"})
        |> send_resp
        |> halt

      [first | _] ->
        [bucket, key] = String.split(first, "/", parts: 2)

        conn
        |> merge_assigns(bucket: bucket, key: key)
    end
  end
end
