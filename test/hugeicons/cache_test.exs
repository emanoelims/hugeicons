defmodule Hugeicons.CacheTest do
  use ExUnit.Case, async: true

  alias Hugeicons.Cache
  alias Hugeicons.Config
  alias Hugeicons.RegistryStub

  @moduletag :tmp_dir
  @req [plug: {Req.Test, Hugeicons.Fetcher}, retry: false]
  @npm "https://registry.npmjs.org"
  @pro "https://npm.hugeicons.com"
  @icon File.read!("test/fixtures/icons/stroke-rounded/FirstBracketIcon.js")

  setup %{tmp_dir: tmp} do
    tarball = RegistryStub.tarball(%{"FirstBracketIcon" => @icon}, tmp)
    RegistryStub.stub(@npm, "@hugeicons/core-free-icons", tarball)
    %{config: Config.new!(styles: ["stroke-rounded"], cache_dir: Path.join(tmp, "cache")), tarball: tarball}
  end

  defp downloads do
    receive do
      {:request, "GET", url, _headers} -> if(String.ends_with?(url, ".tgz"), do: 1, else: 0) + downloads()
    after
      0 -> 0
    end
  end

  test "downloads a style once and then reads the cache", %{config: config} do
    set = Cache.ensure!(config, "stroke-rounded", @req)

    assert Cache.ensure!(config, "stroke-rounded", @req) == set
    assert File.exists?(Cache.path(config, "stroke-rounded"))
    assert downloads() == 1
  end

  test "parallel callers share one download", %{config: config} do
    1..8
    |> Enum.map(fn _ -> Task.async(fn -> Cache.ensure!(config, "stroke-rounded", @req) end) end)
    |> Task.await_many()
    |> Enum.uniq()
    |> then(&assert length(&1) == 1)

    assert downloads() == 1
  end

  test "downloads again when the origin changes, as when a license key is set", %{config: config, tarball: tarball} do
    assert %{origin: :free} = Cache.ensure!(config, "stroke-rounded", @req)

    RegistryStub.stub(@pro, "@hugeicons-pro/core-stroke-rounded", tarball)
    assert %{origin: :pro} = Cache.ensure!(%{config | license_key: "k"}, "stroke-rounded", @req)
    assert downloads() == 2
  end

  test "replaces a corrupt cache file", %{config: config} do
    path = Cache.path(config, "stroke-rounded")
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, "not a term")

    assert %{icons: %{"FirstBracketIcon" => _}} = Cache.ensure!(config, "stroke-rounded", @req)
    assert downloads() == 1
  end

  test "refresh! always downloads", %{config: config} do
    Cache.ensure!(config, "stroke-rounded", @req)
    Cache.refresh!(config, "stroke-rounded", @req)

    assert downloads() == 2
  end

  test "load! downloads the styles in parallel", %{config: config, tarball: tarball} do
    test = self()
    packages = ~w(@hugeicons-pro/core-stroke-rounded @hugeicons-pro/core-solid-rounded)

    Req.Test.stub(Hugeicons.Fetcher, fn conn ->
      package = Enum.find(packages, &String.starts_with?(conn.request_path, "/" <> &1 <> "/-/"))

      if package do
        # Hold each tarball until the test saw both downloads start: sequential
        # downloads would never get here for the second package.
        send(test, {:downloading, package, self()})
        receive do: (:go -> Plug.Conn.send_resp(conn, 200, tarball))
      else
        [package] = Enum.filter(packages, &(conn.request_path == "/" <> String.replace(&1, "/", "%2F")))
        url = "https://npm.hugeicons.com/#{package}/-/package-1.0.0.tgz"
        integrity = "sha512-" <> Base.encode64(:crypto.hash(:sha512, tarball))

        Req.Test.json(conn, %{
          "dist-tags" => %{"latest" => "1.0.0"},
          "versions" => %{"1.0.0" => %{"dist" => %{"tarball" => url, "integrity" => integrity}}}
        })
      end
    end)

    config = %{config | styles: ["stroke-rounded", "solid-rounded"], license_key: "k"}
    task = Task.async(fn -> Cache.load!(config, @req) end)

    assert_receive {:downloading, first, first_pid}
    assert_receive {:downloading, second, second_pid}
    assert Enum.sort([first, second]) == Enum.sort(packages)

    send(first_pid, :go)
    send(second_pid, :go)

    assert %{"stroke-rounded" => %{origin: :pro}, "solid-rounded" => %{origin: :pro}} = Task.await(task)
  end

  test "load! raises the original error of a failing style", %{config: config} do
    config = %{config | styles: ["stroke-rounded", "solid-rounded"]}

    assert_raise Hugeicons.Error, ~r/solid-rounded is a Hugeicons Pro style/, fn -> Cache.load!(config, @req) end
  end

  test "load! returns every configured style", %{tmp_dir: tmp} do
    config =
      Config.new!(
        styles: ["stroke-rounded", "solid-rounded"],
        source: {:path, "test/fixtures/icons"},
        cache_dir: Path.join(tmp, "cache")
      )

    assert %{
             "stroke-rounded" => %{icons: %{"FirstBracketIcon" => _}},
             "solid-rounded" => %{icons: %{"FavouriteIcon" => _}}
           } =
             Cache.load!(config)

    assert Cache.refresh!(config, "solid-rounded").origin == {:path, Path.expand("test/fixtures/icons")}
    # A path source is read directly, never cached.
    refute File.exists?(Path.join(tmp, "cache"))
  end

  test "defaults to _build/hugeicons" do
    assert Cache.dir(Config.new!([])) == Path.join(Path.dirname(Mix.Project.build_path()), "hugeicons")
  end
end
