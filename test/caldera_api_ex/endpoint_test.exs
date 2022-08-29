defmodule CalderaApi.EndpointTest do
  use ExUnit.Case, async: true
  use Plug.Test

  @opts CalderaApi.Endpoint.init([])
  @test_sha256_1 "165295965be7bba259e7269333394d2481409022c77690fc63f56777757157c4"

  test "it returns pong" do
    conn = conn(:get, "/ping")
    resp = CalderaApi.Endpoint.call(conn, @opts)
    assert resp.state == :sent
    assert resp.status == 200
    assert resp.resp_body == "pong!"
  end

  test "symboliker with invalid sha256" do
    conn = conn(:get, "/hash/test")
    resp = CalderaApi.Endpoint.call(conn, @opts)
    assert resp.state == :sent
    assert resp.status == 400
    assert resp.resp_body == ~s({"error":"invalid sha256 input value"})
  end

  test "symboliker basic: query" do
    # Check the legacy endpoint for a successful redirect.
    conn = conn(:get, "/hash/#{@test_sha256_1}")
    resp = CalderaApi.Endpoint.call(conn, @opts)
    assert resp.state == :sent
    assert resp.status == 307

    # Check the new endpoint for a successful redirect.
    conn = conn(:get, "/file/#{@test_sha256_1}/symboliker")
    resp = CalderaApi.Endpoint.call(conn, @opts)
    assert resp.state == :sent
    assert resp.status == 307
  end

  test "symboliker basic: request" do
    # Submit a new file for processing and receive a 201 confirming so.
    conn = conn(:post, "/file/#{@test_sha256_1}/symboliker")
    resp = CalderaApi.Endpoint.call(conn, @opts)

    assert resp.state == :sent
    assert resp.status == 201

    # Try and hit the same endpoint with a PUT request and get a 200 as the
    # previous was acknowledged first.
    conn = conn(:put, "/file/#{@test_sha256_1}/symboliker")
    resp = CalderaApi.Endpoint.call(conn, @opts)

    assert resp.state == :sent
    assert resp.status == 200
  end

  test "symboliker invalid fvas: request" do
    # Specifying repeat values in a query string in Elixir results in
    # unexpected merging. Here an error response is returned.
    conn =
      conn(
        :post,
        "/file/#{@test_sha256_1}/symboliker",
        %{"fvas" => 1000}
      )

    resp = CalderaApi.Endpoint.call(conn, @opts)

    assert resp.state == :sent
    assert resp.status == 400
  end

  test "tpx basic: query" do
    conn = conn(:get, "/tpx/google.com")
    resp = CalderaApi.Endpoint.call(conn, @opts)

    assert resp.state == :sent
    assert resp.status == 200
  end
end
