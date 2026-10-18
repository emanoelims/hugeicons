defmodule Hugeicons.Converter do
  @moduledoc """
  Turns an icon module from the npm packages into the SVG markup inside `<svg>`.

  Each package file exports an array of `[tag, attributes]` pairs:

      const FirstBracketIcon = [
        ["path", { d: "M6 3C3.6 4.9 2 8.2 2 12", stroke: "currentColor", strokeWidth: "1.5", key: "0" }]
      ];

  which becomes `<path d="M6 3C3.6 4.9 2 8.2 2 12" stroke="currentColor"/>`.

  The output is compiled as HEEx template source, so the package is treated as
  untrusted input: only known SVG tags are accepted, attribute names must be
  identifiers, and every value is HTML-escaped (which also neutralizes `<%` and
  any other template syntax).

  The default stroke width (`1.5`) is dropped from the elements so the root `<svg>`
  can set it for all of them by inheritance; deliberate widths (such as `2` on a
  detail) are kept.
  """

  @typedoc "The SVG markup of one icon, without the `<svg>` element."
  @type svg() :: String.t()

  @tags ~w(path circle rect line ellipse polyline polygon g)
  @default_stroke_width "1.5"

  @element ~r/\[\s*"([^"]+)"\s*,\s*\{([^}]*)\}\s*\]/
  @attribute ~r/([A-Za-z][A-Za-z0-9]*)\s*:\s*(?:"([^"]*)"|'([^']*)'|(-?[\d.]+))/

  @doc """
  Converts the source of an icon module into SVG markup.

      iex> Hugeicons.Converter.to_svg(~S|[["circle", { cx: "12", cy: "12", r: "3", strokeWidth: "1.5", key: "0" }]]|)
      {:ok, ~S|<circle cx="12" cy="12" r="3"/>|}

      iex> Hugeicons.Converter.to_svg("export default 42;")
      {:error, :no_elements}
  """
  @spec to_svg(String.t()) :: {:ok, svg()} | {:error, :no_elements | {:unknown_tag, String.t()}}
  def to_svg(source) when is_binary(source) do
    case Regex.scan(@element, source) do
      [] -> {:error, :no_elements}
      elements -> elements |> Enum.map(&element/1) |> collect()
    end
  end

  defp element([_, tag, attributes]) when tag in @tags do
    attributes =
      @attribute
      |> Regex.scan(attributes)
      |> Enum.map(&attribute/1)
      |> Enum.reject(&drop?/1)
      |> Enum.map(fn {name, value} -> [?\s, name, ~s(="), escape(value), ?"] end)

    {:ok, IO.iodata_to_binary([?<, tag, attributes, "/>"])}
  end

  defp element([_, tag, _attributes]), do: {:error, {:unknown_tag, tag}}

  defp collect(results) do
    results
    |> Enum.reduce_while({:ok, []}, fn
      {:ok, markup}, {:ok, acc} -> {:cont, {:ok, [acc, markup]}}
      {:error, _reason} = error, _acc -> {:halt, error}
    end)
    |> case do
      {:ok, iodata} -> {:ok, IO.iodata_to_binary(iodata)}
      error -> error
    end
  end

  defp attribute([_, name, value]), do: {kebab(name), value}
  defp attribute([_, name, "", value]), do: {kebab(name), value}
  defp attribute([_, name, "", "", value]), do: {kebab(name), value}

  defp drop?({"key", _value}), do: true
  defp drop?({"stroke-width", @default_stroke_width}), do: true
  defp drop?(_attribute), do: false

  defp kebab(name), do: name |> String.replace(~r/([a-z0-9])([A-Z])/, "\\1-\\2") |> String.downcase()

  defp escape(value), do: value |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
end
