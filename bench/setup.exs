# Shared setup of the benchmark scripts (`mise run bench`).
#
# Installs this checkout of the library with Mix.install, configured for the free
# `stroke-rounded` style from npm, so the scripts measure the real icons instead of
# the repository's fixtures (config/config.exs is not read by Mix.install). The
# install, its build and the downloaded icons live in `_build/bench`, which Git
# ignores. The first run downloads the icons here, before any timed section.

# Never benchmark Pro icons: without a key, the free package is downloaded.
System.delete_env("HUGEICONS_LICENSE_KEY")

repo_dir = Path.expand("..", __DIR__)
bench_build = Path.join(repo_dir, "_build/bench")
System.put_env("MIX_INSTALL_DIR", Path.join(bench_build, "install"))

Mix.install([{:hugeicons, path: repo_dir}],
  # The repository's lockfile, so the benchmarks use the versions CI tests.
  lockfile: :hugeicons,
  config: [
    hugeicons: [
      styles: ["stroke-rounded"],
      source: :npm,
      cache_dir: Path.join(bench_build, "hugeicons")
    ]
  ]
)

defmodule Bench do
  @moduledoc false

  @doc "The root of this checkout."
  def repo_dir, do: Path.expand("..", __DIR__)

  @doc "The configuration the library was compiled with."
  def config, do: Hugeicons.Config.new!(Application.get_all_env(:hugeicons))

  @doc "The downloaded free icon set (read from the warm cache)."
  def icon_set, do: config() |> Hugeicons.Cache.load!() |> Map.fetch!("stroke-rounded")

  @doc "Prints a title and the environment the numbers come from."
  def header(title) do
    set = icon_set()

    IO.puts("""
    ## #{title}

    Elixir #{System.version()} / OTP #{System.otp_release()}, \
    phoenix_live_view #{Application.spec(:phoenix_live_view, :vsn)}, \
    #{System.schedulers_online()} schedulers, \
    #{delimit(map_size(set.icons))} free icons (@hugeicons/core-free-icons #{set.version}).
    """)
  end

  @doc "Prints a Markdown table."
  def table(headers, rows) do
    line = fn cells -> "| " <> Enum.join(cells, " | ") <> " |" end

    IO.puts(
      Enum.join(
        [line.(headers), line.(Enum.map(headers, fn _ -> "---" end)) | Enum.map(rows, line)],
        "\n"
      ) <> "\n"
    )
  end

  @doc "Formats a byte count as `21,984 B`."
  def bytes(count), do: delimit(count) <> " B"

  @doc "Formats a byte count in megabytes."
  def megabytes(count), do: :erlang.float_to_binary(count / 1_000_000, decimals: 1) <> " MB"

  @doc "Formats microseconds as seconds."
  def seconds(microseconds), do: :erlang.float_to_binary(microseconds / 1_000_000, decimals: 2) <> " s"

  defp delimit(count) do
    count
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end
end
