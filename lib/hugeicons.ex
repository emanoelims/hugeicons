defmodule Hugeicons do
  @moduledoc """
  [Hugeicons](https://hugeicons.com) as a Phoenix function component.

      <.hugeicons_icon icon="FirstBracketIcon" />
      <.hugeicons_icon icon="FirstBracketIcon" variant="solid-sharp" size={20} class="text-zinc-500" />

  Icons are named like the npm exports (`FirstBracketIcon`), so names copied from
  the Hugeicons website work as they are. Import the component in the `html_helpers`
  of your web module:

      defp html_helpers do
        quote do
          import Hugeicons, only: [hugeicons_icon: 1]
          # ...
        end
      end

  Icons render as inline SVG: each `<path>` is in the DOM, so CSS can animate it,
  browsers' page translation leaves it alone and nothing depends on a font loading.

  The styles to compile are set in `config :hugeicons, styles: [...]` (see
  `Hugeicons.Config`). The free `stroke-rounded` style needs nothing else; the Pro
  styles are downloaded with your own license key, read from `HUGEICONS_LICENSE_KEY`.
  """
  use Phoenix.Component

  alias Hugeicons.Chunk
  alias Hugeicons.Style

  require Hugeicons.Config

  config = Hugeicons.Config.compile_env()
  sets = Hugeicons.Cache.load!(config)

  for style <- config.styles, cache = Hugeicons.Cache.path(config, style), File.exists?(cache) do
    @external_resource cache
  end

  @variants config.styles
  @default_variant config.default_variant
  @names sets |> Enum.flat_map(fn {_style, set} -> Map.keys(set.icons) end) |> Enum.uniq() |> Enum.sort()

  @doc """
  Lists the icon names compiled in any configured variant, sorted.

  Useful to validate names that come from data, such as a column holding an icon:

      validate_inclusion(changeset, :icon, Hugeicons.names())
  """
  @spec names() :: [String.t()]
  def names, do: @names

  @doc "Lists the configured variants (styles); the first one is the default."
  @spec variants() :: [Style.t()]
  def variants, do: [@default_variant | List.delete(@variants, @default_variant)]

  @doc """
  Renders an icon as inline SVG.

  Mirrors the props of the official `HugeiconsIcon` component of Vue, React,
  Svelte and Angular.

  `icon` is the icon name as exported by the npm packages, such as
  `"FirstBracketIcon"`. A literal name that was not compiled produces a warning at
  compile time; a name computed at runtime raises `ArgumentError` with a suggestion.

  ## Accessibility

  An icon without an inner block is decorative: it renders `aria-hidden="true"`.
  Pass a `<title>` as the inner block to give it an accessible name; the icon then
  renders `role="img"` and no `aria-hidden`, so assistive technology announces it:

      <.hugeicons_icon icon="Cancel01Icon">
        <title>Close</title>
      </.hugeicons_icon>

  An `aria-label` or `aria-labelledby` also names the icon and renders `role="img"`.
  For a name that may be missing, prefer `aria-label={@label}`: a `nil` label leaves
  the icon decorative, while any inner block exposes it, even one that renders
  nothing (`<title :if={@label}>`).

  A `role` or `aria-hidden` you pass yourself always wins and is rendered once.

  ## Examples

      <.hugeicons_icon icon="Home01Icon" />
      <.hugeicons_icon icon="Home01Icon" variant="solid-rounded" size={20} stroke_width={2} />
      <.hugeicons_icon
        icon="FavouriteIcon"
        alt_icon="FavouriteIcon"
        alt_variant="solid-rounded"
        show_alt={@liked}
        class="text-rose-500"
      />
  """
  @doc type: :component
  attr :icon, :string, required: true, values: @names, doc: "the icon name, like `\"FirstBracketIcon\"`."
  attr :variant, :string, default: @default_variant, values: @variants, doc: "the style to render."
  attr :alt_icon, :string, default: nil, values: [nil | @names], doc: "the icon shown instead when `show_alt` is true."
  attr :alt_variant, :string, values: @variants, doc: "the style of `alt_icon`. Defaults to `variant`."
  attr :show_alt, :boolean, default: false, doc: "shows `alt_icon` instead of `icon`."
  attr :size, :any, default: 24, doc: "the width and height."
  attr :color, :string, default: "currentColor", doc: "the icon color."
  attr :stroke_width, :any, default: 1.5, doc: "the width of the strokes drawn with the default width."

  attr :absolute_stroke_width, :boolean,
    default: false,
    doc: "keeps the stroke width constant on screen whatever the `size`."

  # No `fill`: the root's static `fill="none"` lets each element choose its fill,
  # and a caller's `fill` would render a second, ignored `fill` attribute.
  attr :rest, :global,
    include: ~w(stroke),
    doc: """
    They go to the `<svg>`. With an inner block, `aria-label` or `aria-labelledby`, `role="img"` \
    is added; otherwise `aria-hidden="true"`. Your own `aria-hidden` and `role` take precedence.\
    """

  slot :inner_block, doc: "markup placed first inside `<svg>`, such as a `<title>`."

  @spec hugeicons_icon(map()) :: Phoenix.LiveView.Rendered.t()
  def hugeicons_icon(assigns) do
    # Without an explicit alt_variant, the alternative icon uses the same style.
    assigns
    |> assign_new(:alt_variant, fn %{variant: variant} -> variant end)
    |> svg()
  end

  # Lookups stay inside template expressions so HEEx re-runs them only when their
  # inputs change; a derived assign would resend the paths on every render.
  #
  # HEEx resends an expression when any assign it references changes, whatever the
  # branch taken, so `stroke-width` reads `@size` only in the template for absolute
  # widths: with relative widths, changing `size` does not resend it.
  #
  # The global attributes and the accessibility defaults share one expression: the
  # caller's globals exist only in `@rest`, and a separate `aria-hidden={...}` or
  # `role={...}` would render twice whenever the caller also passes it.
  defp svg(%{absolute_stroke_width: true} = assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      width={@size}
      height={@size}
      fill="none"
      color={@color}
      stroke-width={absolute_stroke_width(@stroke_width, @size)}
      {global_attrs(@rest, @inner_block)}
    >{render_slot(@inner_block)}{inner!(@show_alt, @icon, @variant, @alt_icon, @alt_variant)}</svg>
    """
  end

  defp svg(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      width={@size}
      height={@size}
      fill="none"
      color={@color}
      stroke-width={@stroke_width}
      {global_attrs(@rest, @inner_block)}
    >{render_slot(@inner_block)}{inner!(@show_alt, @icon, @variant, @alt_icon, @alt_variant)}</svg>
    """
  end

  defp absolute_stroke_width(width, size) when is_number(width) and is_number(size) and size > 0, do: width * 24 / size
  defp absolute_stroke_width(width, _size), do: width

  # A decorative icon is hidden from assistive technology; one with an accessible
  # name (an inner block such as a `<title>`, or `aria-label`/`aria-labelledby`) is
  # exposed as an image. The caller's own values win.
  defp global_attrs(rest, inner_block) when is_map(rest) do
    if inner_block != [] or named?(rest),
      do: put_default(rest, :role, "img"),
      else: put_default(rest, :"aria-hidden", "true")
  end

  defp named?(rest), do: Enum.any?([:"aria-label", :"aria-labelledby"], &(global(rest, &1) not in [nil, false, ""]))

  # A nil value renders nothing, so it counts as not given and the default applies.
  defp put_default(rest, key, value), do: if(global(rest, key) == nil, do: Map.put(rest, key, value), else: rest)

  # Callers' globals have atom keys; an explicit `rest` map may use strings.
  defp global(rest, key), do: Map.get(rest, key, Map.get(rest, Atom.to_string(key)))

  defp inner!(true, _icon, _variant, alt_icon, alt_variant) when is_binary(alt_icon), do: lookup!(alt_icon, alt_variant)
  defp inner!(_show_alt, icon, variant, _alt_icon, _alt_variant), do: lookup!(icon, variant)

  defp lookup!(name, variant) when is_binary(name) and is_binary(variant) do
    Chunk.inner(variant, name) || raise ArgumentError, unknown_icon(name, variant)
  end

  defp lookup!(name, variant) do
    raise ArgumentError, "expected icon and variant to be strings, got: #{inspect(name)} and #{inspect(variant)}"
  end

  defp unknown_icon(name, variant) do
    cond do
      variant not in @variants ->
        "variant #{inspect(variant)} was not compiled; configured variants: #{inspect(@variants)}"

      name in @names ->
        "Hugeicon #{inspect(name)} does not exist in #{inspect(variant)}"

      true ->
        "unknown Hugeicon #{inspect(name)}" <> suggestion(name)
    end
  end

  defp suggestion(name) do
    case Enum.max_by(@names, &String.jaro_distance(&1, name), fn -> nil end) do
      nil -> ""
      closest -> ", did you mean #{inspect(closest)}?"
    end
  end
end
