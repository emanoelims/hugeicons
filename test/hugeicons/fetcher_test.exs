defmodule Hugeicons.FetcherTest do
  use ExUnit.Case, async: true

  alias Hugeicons.Config
  alias Hugeicons.Error
  alias Hugeicons.Fetcher
  alias Hugeicons.RegistryStub

  @moduletag :tmp_dir
  @req [plug: {Req.Test, Fetcher}, retry: false]
  @npm "https://registry.npmjs.org"
  @pro "https://npm.hugeicons.com"
  @icon File.read!("test/fixtures/icons/stroke-rounded/FirstBracketIcon.js")

  defp config(key \\ nil), do: %{Config.new!(styles: ["stroke-rounded"]) | license_key: key}

  test "downloads the free style from npm without credentials", %{tmp_dir: tmp} do
    RegistryStub.stub(@npm, "@hugeicons/core-free-icons", RegistryStub.tarball(%{"FirstBracketIcon" => @icon}, tmp))

    assert %{version: "1.0.0", origin: :free, icons: %{"FirstBracketIcon" => "<path " <> _}} =
             Fetcher.fetch!("stroke-rounded", config(), @req)

    assert_received {:mix_shell, :info, ["hugeicons: downloading @hugeicons/core-free-icons 1.0.0"]}
    assert_received {:mix_shell, :info, ["hugeicons: downloaded @hugeicons/core-free-icons 1.0.0 (0.0 MB in " <> _]}
    assert_received {:request, "GET", @npm <> "/@hugeicons%2Fcore-free-icons", headers}
    assert {"accept", "application/vnd.npm.install-v1+json" <> _} = List.keyfind(headers, "accept", 0)
    refute List.keyfind(headers, "authorization", 0)
  end

  test "with a license key, downloads from the Pro registry with the key as bearer token", %{tmp_dir: tmp} do
    tarball = RegistryStub.tarball(%{"FirstBracketIcon" => @icon}, tmp)
    RegistryStub.stub(@pro, "@hugeicons-pro/core-solid-sharp", tarball)

    assert %{origin: :pro} = Fetcher.fetch!("solid-sharp", config("key-123"), @req)

    assert_received {:request, "GET", @pro <> "/@hugeicons-pro%2Fcore-solid-sharp", metadata_headers}
    assert_received {:request, "GET", @pro <> "/@hugeicons-pro/core-solid-sharp/-/package-1.0.0.tgz", tarball_headers}
    assert {"authorization", "Bearer key-123"} in metadata_headers
    assert {"authorization", "Bearer key-123"} in tarball_headers
  end

  test "a Pro style without a license key fails before any request" do
    assert_raise Error, ~r/solid-sharp is a Hugeicons Pro style: set HUGEICONS_LICENSE_KEY/, fn ->
      Fetcher.fetch!("solid-sharp", config(), @req)
    end

    refute_received {:request, _, _, _}
  end

  test "never sends the key to a tarball on another host", %{tmp_dir: tmp} do
    tarball = RegistryStub.tarball(%{"FirstBracketIcon" => @icon}, tmp)
    RegistryStub.stub(@pro, "@hugeicons-pro/core-solid-sharp", tarball, tarball_url: "https://evil.example/x.tgz")

    error = assert_raise Error, fn -> Fetcher.fetch!("solid-sharp", config("key-123"), @req) end

    assert error.message =~ "refusing to download @hugeicons-pro/core-solid-sharp from https://evil.example"
    refute error.message =~ "key-123"
    refute_received {:request, _, "https://evil.example" <> _, _}
  end

  test "refuses plain HTTP tarballs", %{tmp_dir: tmp} do
    tarball = RegistryStub.tarball(%{"FirstBracketIcon" => @icon}, tmp)
    RegistryStub.stub(@npm, "@hugeicons/core-free-icons", tarball, tarball_url: "http://registry.npmjs.org/x.tgz")

    assert_raise Error, ~r/refusing to download/, fn -> Fetcher.fetch!("stroke-rounded", config(), @req) end
  end

  test "verifies the tarball against the registry's hash", %{tmp_dir: tmp} do
    tarball = RegistryStub.tarball(%{"FirstBracketIcon" => @icon}, tmp)

    RegistryStub.stub(@npm, "@hugeicons/core-free-icons", tarball, integrity: :shasum)
    assert %{icons: %{"FirstBracketIcon" => _}} = Fetcher.fetch!("stroke-rounded", config(), @req)

    RegistryStub.stub(@npm, "@hugeicons/core-free-icons", tarball, integrity: {:wrong, :sha512})
    assert_raise Error, ~r/does not match its integrity hash/, fn -> Fetcher.fetch!("stroke-rounded", config(), @req) end

    RegistryStub.stub(@npm, "@hugeicons/core-free-icons", tarball, integrity: :none)
    assert_raise Error, ~r/no integrity hash/, fn -> Fetcher.fetch!("stroke-rounded", config(), @req) end
  end

  test "explains a refused license key without echoing it", %{tmp_dir: tmp} do
    RegistryStub.stub(@pro, "@hugeicons-pro/core-solid-sharp", RegistryStub.tarball(%{}, tmp), status: 401)

    error = assert_raise Error, fn -> Fetcher.fetch!("solid-sharp", config("key-123"), @req) end
    assert error.message =~ "refused access to @hugeicons-pro/core-solid-sharp (HTTP 401): check HUGEICONS_LICENSE_KEY"
    refute error.message =~ "key-123"
  end

  test "reports missing packages and empty tarballs", %{tmp_dir: tmp} do
    RegistryStub.stub(@npm, "@hugeicons/core-free-icons", RegistryStub.tarball(%{}, tmp), status: 404)
    assert_raise Error, ~r/was not found/, fn -> Fetcher.fetch!("stroke-rounded", config(), @req) end

    RegistryStub.stub(@npm, "@hugeicons/core-free-icons", RegistryStub.tarball(%{}, tmp))
    assert_raise Error, ~r/no icons found/, fn -> Fetcher.fetch!("stroke-rounded", config(), @req) end
  end

  test "a broken icon names the file it came from", %{tmp_dir: tmp} do
    RegistryStub.stub(@npm, "@hugeicons/core-free-icons", RegistryStub.tarball(%{"BrokenIcon" => "nope"}, tmp))
    assert_raise Error, ~r/could not convert BrokenIcon/, fn -> Fetcher.fetch!("stroke-rounded", config(), @req) end
  end

  test "a path source reads <dir>/<style>/*Icon.js" do
    config = Config.new!(styles: ["solid-rounded"], source: {:path, "test/fixtures/icons"})

    assert %{version: "path", origin: {:path, _}, icons: icons} = Fetcher.fetch!("solid-rounded", config)
    assert Map.keys(icons) == ["FavouriteIcon", "Home01Icon"]

    assert_raise Error, ~r/no \*Icon.js files/, fn -> Fetcher.fetch!("bulk-rounded", config) end
  end
end
