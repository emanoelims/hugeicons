defmodule Demo.Icons do
  @moduledoc """
  Searches the icon names compiled by the `hugeicons` dependency.

  The demo compiles only the free `stroke-rounded` style (see `config/config.exs`).
  """

  # Downcased once at compile time, since every keystroke scans ~6,000 names.
  @index Enum.map(Hugeicons.names(), &{&1, String.downcase(&1)})

  @doc "Returns how many icons were compiled."
  @spec count() :: non_neg_integer()
  def count, do: length(@index)

  @doc """
  Returns the names that contain every word of `query`, ignoring case.

  Names that start with the first word come first; the rest keep alphabetical
  order. An empty query returns every name.

      iex> "ArrowRight01Icon" in Demo.Icons.search("arrow right")
      true
  """
  @spec search(String.t()) :: [String.t()]
  def search(query) when is_binary(query) do
    case words(query) do
      [] ->
        Hugeicons.names()

      [first | _] = words ->
        @index
        |> Enum.filter(fn {_name, key} -> Enum.all?(words, &String.contains?(key, &1)) end)
        |> Enum.sort_by(fn {_name, key} -> not String.starts_with?(key, first) end)
        |> Enum.map(fn {name, _key} -> name end)
    end
  end

  defp words(query), do: query |> String.downcase() |> String.split(~r/[^a-z0-9]+/, trim: true)
end
