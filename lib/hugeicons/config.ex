defmodule Hugeicons.Config do
  @moduledoc """
  The compile-time configuration of the icons.

      # config/config.exs
      config :hugeicons,
        styles: ["stroke-rounded", "solid-rounded"],
        default_variant: "stroke-rounded"

  * `:styles` - the styles to download and compile. Defaults to `["stroke-rounded"]`,
    the free style. Any other style needs a Pro license key.
  * `:default_variant` - the style used when a component is not given `variant`.
    Defaults to the first of `:styles`.
  * `:source` - where icons come from: `:npm` (default) downloads them from the npm
    registries; `{:path, dir}` reads `dir/<style>/*Icon.js` files instead (tests,
    offline or vendored builds).
  * `:version` - the exact package version to download, such as `"4.3.4"`, for
    reproducible builds. Defaults to `nil`, the registry's `latest` release. Every
    style comes from the same tier (the Pro registry with a license key, the free
    package without one), so one version covers them all; but the free and Pro
    packages are numbered separately, so pin a version of the tier in use. Ignored by
    a `{:path, dir}` source.
  * `:cache_dir` - where downloaded icons are kept. Defaults to `_build/hugeicons`
    of the project being compiled.

  The Pro license key is read from the `HUGEICONS_LICENSE_KEY` environment variable,
  never from config files, so it stays out of the repository.
  """

  alias Hugeicons.Style

  @typedoc "Where icons are read from."
  @type source() :: :npm | {:path, Path.t()}

  @typedoc "The validated configuration."
  @type t() :: %__MODULE__{
          styles: [Style.t(), ...],
          default_variant: Style.t(),
          source: source(),
          version: String.t() | nil,
          cache_dir: Path.t() | nil,
          license_key: String.t() | nil
        }

  # The key must never reach logs or error messages through inspect/1.
  @derive {Inspect, except: [:license_key]}
  @enforce_keys [:styles, :default_variant, :source]
  defstruct [:styles, :default_variant, :source, :version, :cache_dir, :license_key]

  @license_env "HUGEICONS_LICENSE_KEY"

  @doc """
  Reads the `:hugeicons` configuration with `Application.compile_env/3`.

  Being a macro, it records the keys in the module that calls it, so Mix recompiles
  that module when the configuration changes.
  """
  defmacro compile_env do
    quote do
      Hugeicons.Config.new!(
        styles: Application.compile_env(:hugeicons, :styles, [Hugeicons.Style.free()]),
        default_variant: Application.compile_env(:hugeicons, :default_variant),
        source: Application.compile_env(:hugeicons, :source, :npm),
        version: Application.compile_env(:hugeicons, :version),
        cache_dir: Application.compile_env(:hugeicons, :cache_dir)
      )
    end
  end

  @doc """
  Validates `opts` and reads the license key from the environment.

  Raises `ArgumentError` with the offending value when an option is invalid.

      iex> config = Hugeicons.Config.new!(styles: ["stroke-rounded"])
      iex> {config.default_variant, config.source, config.version}
      {"stroke-rounded", :npm, nil}
  """
  @spec new!(keyword()) :: t()
  def new!(opts) do
    styles = styles!(Keyword.get(opts, :styles) || [Style.free()])

    %__MODULE__{
      styles: styles,
      default_variant: default_variant!(Keyword.get(opts, :default_variant), styles),
      source: source!(Keyword.get(opts, :source) || :npm),
      version: version!(Keyword.get(opts, :version)),
      cache_dir: Keyword.get(opts, :cache_dir),
      license_key: license_key()
    }
  end

  defp styles!([_ | _] = styles) do
    case Enum.reject(styles, &(&1 in Style.all())) do
      [] ->
        Enum.uniq(styles)

      unknown ->
        raise ArgumentError, "unknown Hugeicons styles #{inspect(unknown)}, expected some of #{inspect(Style.all())}"
    end
  end

  defp styles!(styles) do
    raise ArgumentError, "expected :styles to be a non-empty list of styles, got: #{inspect(styles)}"
  end

  defp default_variant!(nil, [first | _]), do: first

  defp default_variant!(variant, styles) do
    if variant in styles do
      variant
    else
      raise ArgumentError, "expected :default_variant to be one of :styles #{inspect(styles)}, got: #{inspect(variant)}"
    end
  end

  defp source!(:npm), do: :npm
  defp source!({:path, dir} = source) when is_binary(dir), do: source

  defp source!(source) do
    raise ArgumentError, "expected :source to be :npm or {:path, dir}, got: #{inspect(source)}"
  end

  defp version!(nil), do: nil

  defp version!(version) when is_binary(version) do
    case Version.parse(version) do
      {:ok, _version} -> version
      :error -> invalid_version!(version)
    end
  end

  defp version!(version), do: invalid_version!(version)

  defp invalid_version!(version) do
    raise ArgumentError,
          ~s(expected :version to be an exact package version such as "4.3.4", or nil for the latest, ) <>
            "got: #{inspect(version)}"
  end

  defp license_key do
    case System.get_env(@license_env) do
      key when key in [nil, ""] -> nil
      key -> String.trim(key)
    end
  end
end
