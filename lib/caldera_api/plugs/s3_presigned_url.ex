defmodule CalderaApi.Plugs.S3PresignedUrl do
  @moduledoc """
  Given a bucket and a key, assign a presigned url for the desired object.

  ## Plug Assigns

    * `:bucket` - target S3 bucket, required input
    * `:key` - target S3 key, required input

  ## Plug Options

    * `:url_key` - key to assign the url as, default :presigned_url

  ## Examples

  ```
  conn = S3PresignedUrl.call(conn)
  assert Map.has_key?(conn.assigns, :presigned_url)
  ```

  ```
  conn = S3PresignedUrl.call(conn, url_key: :redirect_url)
  assert Map.has_key?(conn.assigns, :redirect_url)
  ```
  """

  use Plug.Builder

  plug(:s3_presigned_url, builder_opts())

  @spec s3_presigned_url(Plug.Conn.t(), Plug.opts()) :: Plug.Conn.t()
  def s3_presigned_url(
        %Plug.Conn{
          assigns: %{bucket: bucket, key: key}
        } = conn,
        opts
      ) do
    url_key = Keyword.get(opts, :url_key, :presigned_url)

    ExAws.Config.new(:s3)
    |> ExAws.S3.presigned_url(:get, bucket, key)
    # XXX: flesh out potential error cases here
    |> case do
      {:ok, url} -> assign(conn, url_key, url)
    end
  end
end
