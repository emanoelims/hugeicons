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
  Stubs `Hugeicons.Fetcher` requests: `package` metadata on `registry`, listing
  `:versions` that all serve `tarball` from `<registry>/<package>/-/package-<version>.tgz`.

  Options: `:versions` (default `["1.0.0"]`), `:latest` (the `latest` dist-tag,
  default the last of `:versions`), `:tarball_url` (one URL for every version),
  `:integrity` (`:sha512` default, `:shasum`, `:none` or `{:wrong, _}`), `:status`
  (HTTP status of every response, default 200).
  """
  @spec stub(String.t(), String.t(), binary(), keyword()) :: :ok
  def stub(registry, package, tarball, opts \\ []) do
    test = self()
    opts = Keyword.put_new(opts, :versions, ["1.0.0"])
    versions = Keyword.fetch!(opts, :versions)

    tarball_urls =
      Map.new(versions, &{&1, Keyword.get(opts, :tarball_url, "#{registry}/#{package}/-/package-#{&1}.tgz")})

    status = Keyword.get(opts, :status, 200)

    Req.Test.stub(Hugeicons.Fetcher, fn conn ->
      url = "#{conn.scheme}://#{conn.host}#{conn.request_path}"
      send(test, {:request, conn.method, url, conn.req_headers})

      cond do
        status != 200 ->
          Plug.Conn.send_resp(conn, status, "")

        url == registry <> "/" <> String.replace(package, "/", "%2F") ->
          Req.Test.json(conn, metadata(tarball, tarball_urls, opts))

        url in Map.values(tarball_urls) ->
          Plug.Conn.send_resp(conn, 200, tarball)

        true ->
          Plug.Conn.send_resp(conn, 404, "")
      end
    end)
  end

  defp metadata(tarball, tarball_urls, opts) do
    dist =
      case Keyword.get(opts, :integrity, :sha512) do
        :sha512 -> %{"integrity" => "sha512-" <> Base.encode64(:crypto.hash(:sha512, tarball))}
        :shasum -> %{"shasum" => Base.encode16(:crypto.hash(:sha, tarball), case: :lower)}
        {:wrong, _} -> %{"integrity" => "sha512-" <> Base.encode64(:crypto.hash(:sha512, "other"))}
        :none -> %{}
      end

    %{
      "dist-tags" => %{"latest" => Keyword.get_lazy(opts, :latest, fn -> List.last(Keyword.fetch!(opts, :versions)) end)},
      "versions" => Map.new(tarball_urls, fn {version, url} -> {version, %{"dist" => Map.put(dist, "tarball", url)}} end)
    }
  end
end
