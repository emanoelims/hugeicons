defmodule Hugeicons.ProTest do
  # Downloads every Pro style with the developer's key (from mise.local.toml):
  #
  #     mise exec -- mix test --only pro
  #
  # Excluded by default. Everything downloaded stays in the test's tmp dir; never
  # copy its output (icon markup) into issues or fixtures.
  use ExUnit.Case, async: false

  alias Hugeicons.Cache
  alias Hugeicons.Config
  alias Hugeicons.Style

  @moduletag :pro
  @moduletag :tmp_dir
  @moduletag timeout: :infinity

  setup do
    key = :persistent_term.get({__MODULE__, :license_key}) || flunk("set HUGEICONS_LICENSE_KEY (mise.local.toml)")

    previous = Mix.shell()
    Mix.shell(Mix.Shell.IO)
    on_exit(fn -> Mix.shell(previous) end)

    %{key: key}
  end

  test "every Pro style downloads, converts and shares the same names", %{key: key, tmp_dir: tmp} do
    # Pro icons must not stay on disk, even in the ignored tmp/ directory.
    on_exit(fn -> File.rm_rf!(tmp) end)
    config = %{Config.new!(styles: Style.all(), cache_dir: tmp) | license_key: key}

    {microseconds, sets} = :timer.tc(fn -> Cache.load!(config) end)
    IO.puts("\nall #{length(Style.all())} styles in #{div(microseconds, 1_000_000)} s")

    reference = sets |> Map.fetch!("stroke-rounded") |> Map.fetch!(:icons) |> Map.keys() |> MapSet.new()

    for style <- Style.all() do
      %{origin: :pro, version: version, icons: icons} = Map.fetch!(sets, style)
      names = icons |> Map.keys() |> MapSet.new()
      explicit = Enum.count(icons, fn {_name, svg} -> svg =~ "stroke-width=" end)
      bytes = config |> Cache.path(style) |> File.stat!() |> Map.fetch!(:size)

      IO.puts(
        "#{String.pad_trailing(style, 16)} #{version}  #{map_size(icons)} icons  " <>
          "#{explicit} with an explicit stroke width  cache #{div(bytes, 1024)} KB"
      )

      assert MapSet.equal?(names, reference),
             "#{style} differs from stroke-rounded: " <>
               "missing #{reference |> MapSet.difference(names) |> Enum.take(5) |> inspect()}, " <>
               "extra #{names |> MapSet.difference(reference) |> Enum.take(5) |> inspect()}"

      # The component's stroke_width only reaches elements drawn with the default
      # width (1.5), which the converter drops; a style with another default would
      # keep it on most icons.
      assert explicit < map_size(icons) * 0.05, "#{style}: #{explicit} icons keep an explicit stroke width"
    end
  end
end
