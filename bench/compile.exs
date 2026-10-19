# Compile time and code size of the icons, with a warm cache.
#
#     mise exec -- elixir bench/compile.exs [--rounds 3]
#
# Compiles the 16 chunk modules from lib/hugeicons/chunks in parallel, as Mix does
# in a host build, and reports the time and the size of the .beam files. The cache
# is warm (setup.exs downloaded the free style before), so the network is not part
# of the timed section; reading and decoding the cache file is, as in a real build.
#
# Two reference implementations put the numbers in context:
#
#   * Map literal: every icon's markup in one map, as approaches A and B of
#     bench/diff.exs need. Fast to compile, but its paths are dynamic strings.
#   * One module: the shipped clauses (a static-only `~H` per icon) in a single
#     module instead of 16, which is why the chunks exist.
#
# One full `~H` per icon with dynamic attributes in a single module is left out:
# it takes minutes to compile (253 s in the design spec).

Code.require_file("setup.exs", __DIR__)

defmodule Bench.Compile do
  @moduledoc false

  def run(rounds) do
    Bench.header("Compile time, one style, cache warm (median of #{rounds} runs)")

    # Every round redefines the same modules.
    Code.put_compiler_option(:ignore_module_conflict, true)

    out = Path.join(Bench.repo_dir(), "_build/bench/ebin")
    chunks = Path.wildcard(Path.join(Bench.repo_dir(), "lib/hugeicons/chunks/*.ex"))

    results = [
      measure("#{length(chunks)} chunk modules in parallel (shipped)", rounds, fn -> compile_files(chunks, out) end),
      measure("Map literal (reference)", rounds, fn -> compile_quoted(map_literal()) end),
      measure("One module (reference)", rounds, fn -> compile_quoted(one_module()) end)
    ]

    Bench.table(["Variant", "Time", "ebin"], results)
  end

  defp measure(label, rounds, fun) do
    runs = for _round <- 1..rounds//1, do: :timer.tc(fun)
    times = runs |> Enum.map(&elem(&1, 0)) |> Enum.sort()
    {_time, size} = hd(runs)

    [label, Bench.seconds(Enum.at(times, div(rounds, 2))), Bench.megabytes(size)]
  end

  # Returns the total size of the .beam files written.
  defp compile_files(files, out) do
    File.rm_rf!(out)
    File.mkdir_p!(out)
    {:ok, _modules, _diagnostics} = Kernel.ParallelCompiler.compile_to_path(files, out, return_diagnostics: true)

    out |> Path.join("*.beam") |> Path.wildcard() |> Enum.map(&File.stat!(&1).size) |> Enum.sum()
  end

  # Returns the size of the compiled module.
  defp compile_quoted(quoted) do
    [{_module, binary}] = Code.compile_quoted(quoted)
    byte_size(binary)
  end

  defp map_literal do
    quote do
      defmodule Bench.MapLiteral do
        @moduledoc false
        config = Hugeicons.Config.new!(Application.get_all_env(:hugeicons))
        @icons config |> Hugeicons.Cache.load!() |> Map.fetch!("stroke-rounded") |> Map.fetch!(:icons)

        def svg(name), do: Map.fetch(@icons, name)
      end
    end
  end

  # Hugeicons.Chunk.__using__/1 without the split by name.
  defp one_module do
    # The unquotes below are unquote fragments of the generated module body.
    quote unquote: false do
      defmodule Bench.OneModule do
        @moduledoc false
        import Phoenix.Component, only: [sigil_H: 2]

        config = Hugeicons.Config.new!(Application.get_all_env(:hugeicons))

        for {style, set} <- Hugeicons.Cache.load!(config), {name, svg} <- set.icons do
          def inner(unquote(style), unquote(name)) do
            var!(assigns) = %{}
            _ = var!(assigns)
            sigil_H(<<unquote(svg)>>, [])
          end
        end

        def inner(_variant, _name), do: nil
      end
    end
  end
end

{opts, _args} = OptionParser.parse!(System.argv(), strict: [rounds: :integer])

case Keyword.get(opts, :rounds, 3) do
  rounds when rounds > 0 -> Bench.Compile.run(rounds)
  rounds -> raise ArgumentError, "expected --rounds to be positive, got: #{rounds}"
end
