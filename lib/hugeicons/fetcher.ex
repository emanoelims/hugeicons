defmodule Hugeicons.Fetcher do
  @moduledoc """
  Downloads a style's npm package and converts its icons.

  The version downloaded is the configured `:version` when one is pinned, or else the
  registry's `latest` dist-tag.

  The free style comes from the public npm registry. With a license key, every
  style (the free one included) comes from Hugeicons' private registry, which
  authenticates with the key as a bearer token, as `.npmrc` does.

  The key is only ever sent over HTTPS to the private registry's host: a tarball
  URL that points anywhere else is refused before the request is made. Tarballs
  are checked against the registry's integrity hash before they are unpacked.
  """

  alias Hugeicons.Config
  alias Hugeicons.Converter
  alias Hugeicons.Error
  alias Hugeicons.Style

  @typedoc "Where an icon set came from."
  @type origin() :: Style.tier() | {:path, Path.t()}

  @typedoc "The icons of one style, keyed by their npm export name (`\"FirstBracketIcon\"`)."
  @type icon_set() :: %{version: String.t(), origin: origin(), icons: %{String.t() => Converter.svg()}}

  @npm_registry "https://registry.npmjs.org"
  @pro_registry "https://npm.hugeicons.com"
  @abbreviated_metadata "application/vnd.npm.install-v1+json; q=1.0, application/json; q=0.8"

  @tarball_icon ~r{\Apackage/dist/esm/(?:[^/]+/)*([A-Z][A-Za-z0-9]*Icon)\.js\z}
  @path_icon ~r{\A([A-Z][A-Za-z0-9]*Icon)\.js\z}

  @doc """
  Returns where `style` would be read from under `config`.

  Raises `Hugeicons.Error` for a Pro style when there is no license key.
  """
  @spec origin(Style.t(), Config.t()) :: origin()
  def origin(_style, %Config{source: {:path, dir}}), do: {:path, Path.expand(dir)}
  def origin(_style, %Config{license_key: key}) when is_binary(key), do: :pro

  def origin(style, %Config{}) do
    if style == Style.free() do
      :free
    else
      raise Error,
            "#{style} is a Hugeicons Pro style: set HUGEICONS_LICENSE_KEY to your Universal License Key, " <>
              "or configure only #{inspect(Style.free())}"
    end
  end

  @doc """
  Fetches and converts the icons of `style`.

  `req_options` are merged into the `Req` request (tests use them to plug a stub).
  """
  @spec fetch!(Style.t(), Config.t(), keyword()) :: icon_set()
  def fetch!(style, %Config{} = config, req_options \\ []) do
    case origin(style, config) do
      {:path, dir} = origin -> %{version: "path", origin: origin, icons: read_dir!(dir, style)}
      tier -> download!(style, tier, config, req_options)
    end
  end

  defp download!(style, tier, %Config{license_key: key, version: pinned}, req_options) do
    # Downloads run at compile time, before any application is started.
    {:ok, _apps} = Application.ensure_all_started(:req)
    registry = registry(tier)
    package = Style.package(style, tier)

    req =
      [base_url: registry, headers: auth_headers(tier, key), retry: :transient, decode_body: false]
      |> Req.new()
      |> Req.merge(req_options)

    metadata =
      req
      |> get!("/" <> String.replace(package, "/", "%2F"), package, headers: [accept: @abbreviated_metadata])
      |> decode_metadata!(package)

    version = pinned || get_in(metadata, ["dist-tags", "latest"])
    dist = dist!(metadata, version, pinned, package)
    tarball_url = same_host!(dist["tarball"], registry, package)

    info("downloading #{package} #{version}")
    {microseconds, tarball} = :timer.tc(fn -> get!(req, tarball_url, package) end)
    info("downloaded #{package} #{version} (#{megabytes(byte_size(tarball))} MB in #{seconds(microseconds)} s)")
    verify_integrity!(tarball, dist, package)

    %{version: version, origin: tier, icons: extract!(tarball, package)}
  end

  # Downloads happen inside `mix compile` and can take minutes for the filled Pro
  # styles: say what is going on instead of leaving a silent compiler.
  defp info(message), do: Mix.shell().info("hugeicons: " <> message)

  defp megabytes(bytes), do: :erlang.float_to_binary(bytes / 1_000_000, decimals: 1)
  defp seconds(microseconds), do: :erlang.float_to_binary(microseconds / 1_000_000, decimals: 1)

  defp registry(:free), do: @npm_registry
  defp registry(:pro), do: @pro_registry

  defp auth_headers(:pro, key), do: [authorization: "Bearer " <> key]
  defp auth_headers(:free, _key), do: []

  defp get!(req, url, package, options \\ []) do
    case Req.get(req, [url: url] ++ options) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        body

      {:ok, %Req.Response{status: status}} when status in [401, 403] ->
        raise Error,
              "the registry refused access to #{package} (HTTP #{status}): check HUGEICONS_LICENSE_KEY " <>
                "and that your plan includes this style"

      {:ok, %Req.Response{status: 404}} ->
        raise Error, "#{package} was not found on the registry"

      {:ok, %Req.Response{status: status}} ->
        raise Error, "could not download #{package}: unexpected HTTP #{status}"

      {:error, exception} ->
        raise Error, "could not download #{package}: #{Exception.message(exception)}"
    end
  end

  defp decode_metadata!(body, package) do
    case JSON.decode(body) do
      {:ok, %{} = metadata} -> metadata
      _ -> raise Error, "the registry returned invalid metadata for #{package}"
    end
  end

  # A pinned version that is missing is a configuration mistake: list what exists.
  defp dist!(metadata, version, pinned, package) do
    case metadata do
      %{"versions" => %{^version => %{"dist" => %{} = dist}}} -> dist
      _other when is_binary(pinned) -> raise Error, unpublished_message(package, pinned, metadata)
      _other -> raise Error, "#{package} has no published version"
    end
  end

  @recent_versions 5

  defp unpublished_message(package, pinned, metadata) do
    available =
      case recent_versions(metadata) do
        [] -> "the registry lists no versions"
        versions -> "the most recent are " <> Enum.join(versions, ", ")
      end

    "#{package} #{pinned} is not published (#{available}): set config :hugeicons, :version to a " <>
      "published version, or remove it to use the latest. The free and Pro packages have different version numbers"
  end

  defp recent_versions(%{"versions" => %{} = versions}) do
    versions
    |> Map.keys()
    |> Enum.flat_map(fn version ->
      case Version.parse(version) do
        {:ok, parsed} -> [parsed]
        :error -> []
      end
    end)
    |> Enum.sort({:desc, Version})
    |> Enum.take(@recent_versions)
    |> Enum.map(&to_string/1)
  end

  defp recent_versions(_metadata), do: []

  # The bearer token follows the tarball request, so it may only go to the registry itself.
  defp same_host!(url, registry, package) when is_binary(url) do
    %URI{scheme: scheme, host: host} = URI.parse(url)

    if scheme == "https" and host == URI.parse(registry).host do
      url
    else
      raise Error, "refusing to download #{package} from #{scheme}://#{host}: expected #{registry}"
    end
  end

  defp same_host!(_url, _registry, package), do: raise(Error, "#{package} metadata has no tarball URL")

  defp verify_integrity!(tarball, %{"integrity" => "sha512-" <> expected}, package) do
    check_digest!(:sha512, tarball, Base.decode64!(expected), package)
  end

  defp verify_integrity!(tarball, %{"shasum" => expected}, package) when is_binary(expected) do
    check_digest!(:sha, tarball, Base.decode16!(expected, case: :mixed), package)
  end

  defp verify_integrity!(_tarball, _dist, package) do
    raise Error, "#{package} metadata has no integrity hash to verify the download"
  end

  defp check_digest!(algorithm, tarball, expected, package) do
    if :crypto.hash(algorithm, tarball) != expected do
      raise Error, "the #{package} tarball does not match its integrity hash"
    end
  end

  defp extract!(tarball, package) do
    files =
      case :erl_tar.extract({:binary, tarball}, [:compressed, :memory]) do
        {:ok, files} -> files
        {:error, reason} -> raise Error, "could not unpack #{package}: #{inspect(reason)}"
      end

    icons =
      for {path, source} <- files,
          [_, name] <- [Regex.run(@tarball_icon, List.to_string(path))],
          into: %{},
          do: {name, convert!(source, name, package)}

    if icons == %{}, do: raise(Error, "no icons found in #{package}: the package layout may have changed")
    icons
  end

  defp read_dir!(dir, style) do
    icons =
      for path <- Path.wildcard(Path.join([dir, style, "*Icon.js"])),
          [_, name] <- [Regex.run(@path_icon, Path.basename(path))],
          into: %{},
          do: {name, path |> File.read!() |> convert!(name, path)}

    if icons == %{}, do: raise(Error, "no *Icon.js files in #{Path.join(dir, style)}")
    icons
  end

  defp convert!(source, name, origin) do
    case Converter.to_svg(source) do
      {:ok, svg} -> svg
      {:error, reason} -> raise Error, "could not convert #{name} from #{origin}: #{inspect(reason)}"
    end
  end
end
