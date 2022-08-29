# CalderaApi

Elixir implementation of Caldera API.

The server is implemented as Plugs on top of Cowboy.

## Installation

First make sure that elixir is installed:

- https://elixir-lang.org/install.html

Then run the following to start the API.

```
$ NATS_HOST="<nats_host>" SONIC_HOST="<sonic_host>" iex -S mix
```

## Code Organization

Common plugs are organized under a single subdirectory:

- `lib/caldera_api/plugs`

While endpoint-specific plugs are organized under respective subdirectories:

- `lib/caldera_api/symboliker`
- `lib/caldera_api/threat_proximity`

Endpoints can store shared constants in a file designated to be loaded with a
`use` call.

```elixir
# lib/caldera_api/foo/constants.ex

defmodule CalderaApi.Foo.Constants do

  defmacro __using__(_) do
    @foo "bar"
    @baz 251
  end

end
```

These constants can be shared by the endpoint-specific plugs in the following
manner.

```elixir
# lib/caldera_api/foo/plug.ex

defmodule CalderaApi.Foo.Plug do

  use CalderaApi.Foo.Constants
  use Plug.Builder

  plug :myplug

  def myplug(conn, _opts) do
    conn
    |> send_resp(@baz, @foo)
  end

end
```

Important note when using `halt()` in Plugs.

`halt()` only prevents downstream plugs from being invoked.

Manual chainings of plugs will not be stopped and without careful watch can
cause "already sent" errors.

```elixir
# lib/caldera_api/bar/plug.ex

defmodule CalderaApi.Bar.Plug do

  use CalderaApi.Bar.Constants
  use Plug.Builder

  plug :myplug

  def myplug(conn, opts) do
    conn = CalderaApi.Foo.Plug.call(
      conn,
      CalderaApi.Foo.Plug.init(opts)
    )

    if conn.state == :sent do
      conn
    else
      conn
      |> put_status(200)
      |> send_resp()
    end
  end

end
```

Distribution Statement "A" (Approved for Public Release, Distribution
Unlimited).
