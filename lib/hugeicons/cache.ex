defmodule Hugeicons.Cache do
  @moduledoc """
  Keeps each downloaded style in the project's build directory.

  Styles are stored one per file (`_build/hugeicons/<style>.etf` by default), so
  adding a style downloads only that one. A cached style is reused while it came
  from the expected origin: setting or removing the license key switches between
  the free and the Pro packages and downloads again.

  This module runs only at compile time (it uses `Mix`). Many modules compile in
  parallel and ask for the same style at once, so the download is serialized with
  a `:global` lock and written atomically.

  A `{:path, dir}` source is read directly, without caching.
  """

  alias Hugeicons.Config
  alias Hugeicons.Fetcher
  alias Hugeicons.Style

  @doc "Returns the directory the styles are cached in."
  @spec dir(Config.t()) :: Path.t()
  def dir(%Config{cache_dir: nil}), do: Path.join(Path.dirname(Mix.Project.build_path()), "hugeicons")
  def dir(%Config{cache_dir: dir}), do: Path.expand(dir)

  @doc "Returns the cache file of `style`."
  @spec path(Config.t(), Style.t()) :: Path.t()
  def path(config, style), do: Path.join(dir(config), style <> ".etf")

  @doc """
  Returns the icon sets of every configured style, downloading the missing ones.
  """
  @spec load!(Config.t()) :: %{Style.t() => Fetcher.icon_set()}
  def load!(%Config{styles: styles} = config), do: Map.new(styles, &{&1, ensure!(config, &1)})

  @doc """
  Returns the icon set of `style`, from the cache when it is current.
  """
  @spec ensure!(Config.t(), Style.t(), keyword()) :: Fetcher.icon_set()
  def ensure!(config, style, req_options \\ []) do
    case Fetcher.origin(style, config) do
      {:path, _dir} ->
        Fetcher.fetch!(style, config, req_options)

      origin ->
        locked(config, style, &current_or_fetch!(&1, origin, style, config, req_options))
    end
  end

  defp current_or_fetch!(path, origin, style, config, req_options) do
    case read(path) do
      {:ok, %{origin: ^origin} = set} -> set
      _stale_or_missing -> write!(path, Fetcher.fetch!(style, config, req_options))
    end
  end

  @doc """
  Downloads `style` again and replaces its cache file.

  Modules that compiled the style track the file, so the next compilation picks up
  the new icons.
  """
  @spec refresh!(Config.t(), Style.t(), keyword()) :: Fetcher.icon_set()
  def refresh!(config, style, req_options \\ []) do
    case Fetcher.origin(style, config) do
      {:path, _dir} -> Fetcher.fetch!(style, config, req_options)
      _origin -> locked(config, style, &write!(&1, Fetcher.fetch!(style, config, req_options)))
    end
  end

  defp locked(config, style, fun) do
    path = path(config, style)
    :global.trans({{__MODULE__, path}, self()}, fn -> fun.(path) end, [node()], :infinity)
  end

  defp read(path) do
    with {:ok, binary} <- File.read(path),
         %{version: version, origin: _, icons: %{}} = set when is_binary(version) <- safe_binary_to_term(binary) do
      {:ok, set}
    else
      _missing_or_invalid -> :error
    end
  end

  defp safe_binary_to_term(binary) do
    :erlang.binary_to_term(binary, [:safe])
  rescue
    ArgumentError -> :error
  end

  defp write!(path, set) do
    File.mkdir_p!(Path.dirname(path))
    tmp = "#{path}.#{System.unique_integer([:positive])}.tmp"
    File.write!(tmp, :erlang.term_to_binary(set, [:compressed]))
    File.rename!(tmp, path)
    set
  end
end
