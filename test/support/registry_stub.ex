defmodule Hugeicons.RegistryStub do
  @moduledoc """
  A fake npm registry for `Req.Test`: serves a package's metadata and tarball, and
  reports every request to the test process as `{:request, method, url, headers}`.
  """

  @doc "Builds a gzipped npm tarball holding `files` (`%{\"FirstBracketIcon\" => source}`)."
  @spec tarball(%{String.t() => String.t()}, Path.t()) :: binary()
  def tarball(files, tmp_dir) do
    path = Path.join(tmp_dir, "package-#{System.unique_integer([:positive])}.tgz")
    entries = for {name, source} <- files, do: {~c"package/dist/esm/#{name}.js", source}
    entries = [{~c"package/package.json", ~s({"name":"x"})} | entries]
    :ok = :erl_tar.create(String.to_charlist(path), entries, [:compressed])
    File.read!(path)
  end

  @doc """
  Stubs `Hugeicons.Fetcher` requests: `package` metadata on `registry`, pointing at
  a tarball served from `tarball_url`.

  Options: `:integrity` (`:sha512` default, `:shasum`, `:none` or `{:wrong, _}`),
  `:status` (HTTP status of every response, default 200).
  """
  @spec stub(String.t(), String.t(), binary(), keyword()) :: :ok
  def stub(registry, package, tarball, opts \\ []) do
    test = self()
    tarball_url = Keyword.get(opts, :tarball_url, "#{registry}/#{package}/-/package-1.0.0.tgz")
    status = Keyword.get(opts, :status, 200)

    Req.Test.stub(Hugeicons.Fetcher, fn conn ->
      url = "#{conn.scheme}://#{conn.host}#{conn.request_path}"
      send(test, {:request, conn.method, url, conn.req_headers})

      cond do
        status != 200 ->
          Plug.Conn.send_resp(conn, status, "")

        url == registry <> "/" <> String.replace(package, "/", "%2F") ->
          Req.Test.json(conn, metadata(tarball, tarball_url, opts))

        url == tarball_url ->
          Plug.Conn.send_resp(conn, 200, tarball)

        true ->
          Plug.Conn.send_resp(conn, 404, "")
      end
    end)
  end

  defp metadata(tarball, tarball_url, opts) do
    dist =
      case Keyword.get(opts, :integrity, :sha512) do
        :sha512 -> %{"integrity" => "sha512-" <> Base.encode64(:crypto.hash(:sha512, tarball))}
        :shasum -> %{"shasum" => Base.encode16(:crypto.hash(:sha, tarball), case: :lower)}
        {:wrong, _} -> %{"integrity" => "sha512-" <> Base.encode64(:crypto.hash(:sha512, "other"))}
        :none -> %{}
      end

    %{
      "dist-tags" => %{"latest" => "1.0.0"},
      "versions" => %{"1.0.0" => %{"dist" => Map.put(dist, "tarball", tarball_url)}}
    }
  end
end
