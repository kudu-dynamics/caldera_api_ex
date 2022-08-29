defmodule CalderaApi.Fishbowl.Request do
  @moduledoc """
  Submit a NATS request for a `fishbowl` parameterized job to be launched for
  ETLing data.

  ## Plug Assigns

    * `:date`          - most datasets are partitioned by date, used to select
                         the partition to process
    * `:date_fmt`      - datasets are partitioned differently, allow them to
                         specify how the date is formatted
    * `:key`           - a specific S3 key to run against
    * `:storage_alias` - the target ETL routine may not match the path in
                         storage, allows requests to specify that
    * `:target`        - the target ETL routine to run

  ## Plug Options
  """

  use CalderaApi.Fishbowl.Constants
  use Plug.Builder

  alias CalderaApi.Plugs
  import Plugs.Json, only: [json: 2]

  plug(:validate_params)
  plug(Plugs.NatsRequest, subject: @nats_subject)
  plug(:respond)

  @spec validate_params(Plug.Conn.t(), Plug.opts()) :: Plug.Conn.t()
  def validate_params(%Plug.Conn{params: params} = conn, _opts) do
    meta_params = [
      "s3_input",
      "target"
    ]

    meta =
      params
      |> process_meta()
      # Drop empty parameters
      |> Enum.reject(fn {_, v} -> is_nil(v) end)
      # Drop unrecognized parameters.
      |> Enum.filter(fn {k, _} -> Enum.member?(meta_params, k) end)
      |> Map.new()

    # DEV: The `max_dispatch` and `max_only_pending` are flags to tell the
    #      pyroclast library underpinning the `nats_to_nomad` service to
    #      make a best effort attempt to limit concurrent executions for
    #      this particular job type.
    conn
    |> assign(:payload, %{
      job_name: @nomad_job,
      meta: meta
    })
  end

  @spec respond(Plug.Conn.t(), Plug.opts()) :: Plug.Conn.t()
  def respond(%Plug.Conn{assigns: %{response: response}} = conn, _opts) do
    # DEV: Remove keys that don't make sense for the current context.
    {_, response} = Map.pop(response, "s3_output")

    conn
    |> json(status: 201, payload: response)
    |> send_resp()
    |> halt()
  end

  defp process_meta(%{"date" => date, "target" => target} = meta) do
    # By default, storage is partitioned {year}/{month}/{day}.
    date_fmt = Map.get(meta, "date_fmt", "%Y-%m-%d")

    # XXX: Assumes that the incoming date is a YYYY-MM-DD string.
    date =
      date
      |> Kernel.<>("T00:00:00")
      |> NaiveDateTime.from_iso8601!()
      |> DateTime.from_naive!("Etc/UTC")
      |> format_datetime(date_fmt)

    # The user may specify a specific file to process.
    key = Map.get(meta, "key", "")

    # The target may have a different name in the S3 bucket.
    path = Map.get(meta, "storage_alias", target)
    version = Map.get(meta, "version", 1)

    %{
      "s3_input" => "s3://#{@s3_bucket}/#{path}/#{version}/#{date}/#{key}",
      "target" => target
    }
  end

  defp process_meta(meta), do: meta

  defp format_datetime(d, fmt) do
    fmt
    |> String.replace("%Y", "#{d.year}" |> String.pad_leading(4, "0"))
    |> String.replace("%m", "#{d.month}" |> String.pad_leading(2, "0"))
    |> String.replace("%d", "#{d.day}" |> String.pad_leading(2, "0"))
  end
end
