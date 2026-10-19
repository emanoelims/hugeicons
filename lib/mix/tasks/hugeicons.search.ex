defmodule Mix.Tasks.Hugeicons.Search do
  @shortdoc "Lists the compiled Hugeicons names matching a term"

  @moduledoc """
  Lists the compiled icon names that match a term, one per line, ready to paste
  into `icon="..."`.

      $ mix hugeicons.search bracket
      $ mix hugeicons.search first bracket --limit 5
      $ mix hugeicons.search FirstBrackeIcon

  Names containing the term come first (those starting with it before the rest),
  ignoring case, spaces, hyphens and underscores; the `Icon` suffix every name
  shares counts only when the term runs into it. When fewer than the limit
  contain it, the names closest to the term (by `String.jaro_distance/2`) follow,
  so a typo or another spelling still finds the icon: `favorite` also lists
  `FavouriteIcon`.

  The task compiles the project first and searches `Hugeicons.names/0`, so it
  lists what your configured styles compiled, Pro styles included.

  ## Options

    * `--limit`, `-n` - the maximum number of names to print (default: 20).
  """
  use Mix.Task

  @requirements ["compile"]

  @default_limit 20

  # Below this Jaro distance (computed without the "Icon" suffix), a name is
  # unrelated noise rather than another spelling of the term.
  @min_distance 0.8

  @impl Mix.Task
  def run(args) do
    {opts, words} = OptionParser.parse!(args, strict: [limit: :integer], aliases: [n: :limit])
    limit = limit!(Keyword.get(opts, :limit, @default_limit))
    term = Enum.join(words, " ")

    case search(Hugeicons.names(), term, limit) do
      [] -> Mix.raise("No compiled icon name matches #{inspect(term)}")
      names -> Enum.each(names, fn name -> Mix.shell().info(name) end)
    end

    :ok
  end

  defp limit!(limit) when limit > 0, do: limit
  defp limit!(limit), do: Mix.raise("--limit must be a positive integer, got: #{limit}")

  # Public only for the tests, which need more names than the fixtures compile.
  @doc false
  @spec search([String.t()], String.t(), pos_integer()) :: [String.t()]
  def search(names, term, limit) do
    term = normalize!(term)
    entries = Enum.map(names, &{normalize(&1), &1})
    {containing, others} = Enum.split_with(entries, fn {normalized, _name} -> contains?(normalized, term) end)
    {prefixed, inner} = Enum.split_with(containing, fn {normalized, _name} -> String.starts_with?(normalized, term) end)
    matches = (prefixed ++ inner) |> Enum.take(limit) |> Enum.map(fn {_normalized, name} -> name end)

    matches ++ closest(others, term, limit - length(matches))
  end

  # Every name ends in "icon", so a term found only in that suffix ("on", "c")
  # says nothing about the name: the first match must start before the suffix.
  # A term running into the suffix ("bracketicon") still matches.
  defp contains?(normalized, term) do
    case :binary.match(normalized, term) do
      {start, _length} -> start < byte_size(stem(normalized))
      :nomatch -> false
    end
  end

  defp closest(_entries, _term, 0), do: []

  defp closest(entries, term, count) do
    stem = stem(term)

    entries
    |> Enum.map(fn {normalized, name} -> {String.jaro_distance(stem(normalized), stem), name} end)
    |> Enum.filter(fn {distance, _name} -> distance >= @min_distance end)
    |> Enum.sort_by(fn {distance, name} -> {-distance, name} end)
    |> Enum.take(count)
    |> Enum.map(fn {_distance, name} -> name end)
  end

  defp normalize!(term) do
    case normalize(term) do
      "" -> Mix.raise("Expected a search term, as in: mix hugeicons.search bracket")
      normalized -> normalized
    end
  end

  defp normalize(text), do: text |> String.downcase() |> String.replace(~r/[^a-z0-9]/, "")

  defp stem(normalized), do: String.replace_suffix(normalized, "icon", "")
end
