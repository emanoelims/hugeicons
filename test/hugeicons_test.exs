defmodule HugeiconsTest do
  use ExUnit.Case, async: true

  import Hugeicons
  import Phoenix.Component, only: [sigil_H: 2]
  import Phoenix.LiveViewTest

  defp svg(html), do: html |> LazyHTML.from_fragment() |> LazyHTML.query("svg")
  defp attr_of(svg, name), do: svg |> LazyHTML.attribute(name) |> List.first()

  test "renders inline SVG with the defaults of the official components" do
    assigns = %{}
    svg = svg(rendered_to_string(~H|<.hugeicons_icon icon="FirstBracketIcon" />|))

    assert attr_of(svg, "viewbox") == "0 0 24 24"
    assert attr_of(svg, "width") == "24"
    assert attr_of(svg, "height") == "24"
    assert attr_of(svg, "fill") == "none"
    assert attr_of(svg, "color") == "currentColor"
    assert attr_of(svg, "stroke-width") == "1.5"
    assert attr_of(svg, "aria-hidden") == "true"
    assert svg |> LazyHTML.query("path") |> Enum.count() == 2
  end

  test "renders the requested variant" do
    assigns = %{}
    html = rendered_to_string(~H|<.hugeicons_icon icon="FavouriteIcon" variant="solid-rounded" />|)

    assert html =~ ~s(<circle cx="12" cy="12" r="8" fill="currentColor">)
  end

  test "swaps to the alternative icon, in the same variant unless told otherwise" do
    assigns = %{on: true}

    same = rendered_to_string(~H|<.hugeicons_icon icon="Home01Icon" alt_icon="FavouriteIcon" show_alt={@on} />|)
    other = rendered_to_string(~H|<.hugeicons_icon
  icon="Home01Icon"
  alt_icon="FavouriteIcon"
  alt_variant="solid-rounded"
  show_alt={@on}
/>|)

    off =
      rendered_to_string(~H|<.hugeicons_icon icon="Home01Icon" alt_icon="FavouriteIcon" alt_variant="solid-rounded" />|)

    assert same =~ "<path"
    refute same =~ "<circle"
    assert other =~ "<circle"
    refute off =~ "<circle"
  end

  test "size, color and stroke width" do
    assigns = %{}

    svg = svg(rendered_to_string(~H|<.hugeicons_icon icon="Home01Icon" size={32} color="red" stroke_width={2} />|))
    assert {attr_of(svg, "width"), attr_of(svg, "color"), attr_of(svg, "stroke-width")} == {"32", "red", "2"}

    absolute =
      svg(rendered_to_string(~H|<.hugeicons_icon icon="Home01Icon" size={48} stroke_width={2} absolute_stroke_width />|))

    assert attr_of(absolute, "stroke-width") == "1.0"

    text_size =
      svg(rendered_to_string(~H|<.hugeicons_icon icon="Home01Icon" size="1em" stroke_width={2} absolute_stroke_width />|))

    assert attr_of(text_size, "stroke-width") == "2"
  end

  test "global attributes reach the svg" do
    assigns = %{}
    svg = svg(rendered_to_string(~H|<.hugeicons_icon icon="Home01Icon" class="size-5" data-x="1" stroke="red" />|))

    assert {attr_of(svg, "class"), attr_of(svg, "data-x"), attr_of(svg, "stroke")} == {"size-5", "1", "red"}
  end

  test "fill is not accepted, so it cannot render a second, ignored fill" do
    warnings =
      ExUnit.CaptureIO.capture_io(:stderr, fn ->
        Code.compile_string("""
        defmodule HugeiconsTest.Fill do
          use Phoenix.Component
          import Hugeicons
          def render(assigns), do: ~H|<.hugeicons_icon icon="Home01Icon" fill="red" />|
        end
        """)
      end)

    assert warnings =~ ~s(undefined attribute "fill" for component Hugeicons.hugeicons_icon/1)
  end

  test "the inner block goes first inside the svg" do
    assigns = %{}
    html = rendered_to_string(~H|<.hugeicons_icon icon="Cancel01Icon">
  <title>Close</title>
</.hugeicons_icon>|)

    assert html =~ ~r{<svg[^>]*>\s*<title>Close</title>\s*<path}
  end

  describe "accessibility" do
    defp occurrences(html, text), do: html |> String.split(text) |> length() |> Kernel.-(1)

    test "an icon without an inner block is hidden from assistive technology" do
      assigns = %{}
      html = rendered_to_string(~H|<.hugeicons_icon icon="Home01Icon" />|)

      assert occurrences(html, "aria-hidden") == 1
      assert attr_of(svg(html), "aria-hidden") == "true"
      assert attr_of(svg(html), "role") == nil
    end

    test "an icon with a title is exposed as an image" do
      assigns = %{}
      html = rendered_to_string(~H|<.hugeicons_icon icon="Cancel01Icon">
  <title>Close</title>
</.hugeicons_icon>|)

      assert attr_of(svg(html), "role") == "img"
      refute html =~ "aria-hidden"
    end

    test "the caller's aria-hidden and role win and are rendered once" do
      assigns = %{hidden: "false"}

      shown = rendered_to_string(~H|<.hugeicons_icon icon="Home01Icon" aria-hidden={@hidden} />|)
      assert occurrences(shown, "aria-hidden") == 1
      assert {attr_of(svg(shown), "aria-hidden"), attr_of(svg(shown), "role")} == {"false", nil}

      titled = rendered_to_string(~H|<.hugeicons_icon icon="Cancel01Icon" role="graphics-symbol" aria-hidden="true">
  <title>Close</title>
</.hugeicons_icon>|)

      assert occurrences(titled, "role") == 1
      assert occurrences(titled, "aria-hidden") == 1
      assert {attr_of(svg(titled), "role"), attr_of(svg(titled), "aria-hidden")} == {"graphics-symbol", "true"}
    end

    test "an aria-label or aria-labelledby exposes the icon as an image" do
      assigns = %{}

      for html <- [
            rendered_to_string(~H|<.hugeicons_icon icon="Home01Icon" aria-label="Home" />|),
            rendered_to_string(~H|<.hugeicons_icon icon="Home01Icon" aria-labelledby="home-label" />|)
          ] do
        assert attr_of(svg(html), "role") == "img"
        refute html =~ "aria-hidden"
      end
    end

    test "a nil label or aria-hidden leaves the icon decorative" do
      assigns = %{label: nil}

      for html <- [
            rendered_to_string(~H|<.hugeicons_icon icon="Home01Icon" aria-label={@label} />|),
            rendered_to_string(~H|<.hugeicons_icon icon="Home01Icon" aria-hidden={@label} />|)
          ] do
        assert {attr_of(svg(html), "aria-hidden"), attr_of(svg(html), "role")} == {"true", nil}
      end
    end

    test "an explicit rest map is honored, whatever its key type" do
      assigns = %{rest: %{"aria-hidden" => "false"}}
      html = rendered_to_string(~H|<.hugeicons_icon icon="Home01Icon" rest={@rest} />|)

      assert occurrences(html, "aria-hidden") == 1
      assert attr_of(svg(html), "aria-hidden") == "false"
    end
  end

  test "a name computed at runtime that does not exist raises with a suggestion" do
    assigns = %{name: "FirstBrackeIcon", other: "Cabinet02Icon"}

    assert_raise ArgumentError, ~s(unknown Hugeicon "FirstBrackeIcon", did you mean "FirstBracketIcon"?), fn ->
      rendered_to_string(~H|<.hugeicons_icon icon={@name} />|)
    end

    assert_raise ArgumentError, ~s(Hugeicon "Cabinet02Icon" does not exist in "solid-rounded"), fn ->
      rendered_to_string(~H|<.hugeicons_icon icon={@other} variant="solid-rounded" />|)
    end
  end

  test "an unknown variant computed at runtime raises with the configured ones" do
    assigns = %{variant: "bulk-rounded"}

    assert_raise ArgumentError, ~r/variant "bulk-rounded" was not compiled/, fn ->
      rendered_to_string(~H|<.hugeicons_icon icon="Home01Icon" variant={@variant} />|)
    end
  end

  test "a literal name that was not compiled warns at compile time" do
    warnings =
      ExUnit.CaptureIO.capture_io(:stderr, fn ->
        Code.compile_string("""
        defmodule HugeiconsTest.Typo do
          use Phoenix.Component
          import Hugeicons
          def render(assigns), do: ~H|<.hugeicons_icon icon="FirstBrackeIcon" />|
        end
        """)
      end)

    assert warnings =~ ~s(attribute "icon" in component Hugeicons.hugeicons_icon/1 must be one of)
    assert warnings =~ ~s(got: "FirstBrackeIcon")
  end

  test "names/0 and variants/0 list what was compiled" do
    assert Hugeicons.names() == ~w(AbacusIcon Cabinet02Icon Cancel01Icon FavouriteIcon FirstBracketIcon Home01Icon)
    assert Hugeicons.variants() == ["stroke-rounded", "solid-rounded"]
  end
end
