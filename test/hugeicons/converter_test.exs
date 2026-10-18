defmodule Hugeicons.ConverterTest do
  use ExUnit.Case, async: true

  alias Hugeicons.Converter

  doctest Converter

  @fixtures "test/fixtures/icons/stroke-rounded"

  test "converts a package icon into elements with kebab-case attributes" do
    {:ok, svg} = Converter.to_svg(File.read!(Path.join(@fixtures, "FirstBracketIcon.js")))

    assert svg ==
             ~s(<path d="M6 3C3.58901 4.93486 2 8.24345 2 12C2 15.7565 3.58901 19.0651 6 21" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round"/>) <>
               ~s(<path d="M18 3C20.411 4.93486 22 8.24345 22 12C22 15.7565 20.411 19.0651 18 21" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round"/>)
  end

  test "drops the default stroke width and keeps deliberate ones" do
    {:ok, svg} = Converter.to_svg(File.read!(Path.join(@fixtures, "Cabinet02Icon.js")))

    refute svg =~ ~s(stroke-width="1.5")
    assert svg |> String.split(~s(stroke-width="2")) |> length() == 3
  end

  test "accepts single-quoted and numeric values" do
    assert Converter.to_svg(~S|[["rect", { x: 2, y: '3', width: 4.5, key: "0" }]]|) ==
             {:ok, ~s(<rect x="2" y="3" width="4.5"/>)}
  end

  test "escapes values, so package data can never become template code" do
    source = ~S|[["path", { d: "<%= System.halt() %> & 'x'", key: "0" }]]|

    assert {:ok, svg} = Converter.to_svg(source)
    refute svg =~ "<%"
    assert svg == ~s|<path d="&lt;%= System.halt() %&gt; &amp; &#39;x&#39;"/>|
  end

  test "an element whose attributes cannot be parsed is not converted" do
    assert Converter.to_svg(~S|[["path", { d: "{@x}" }]]|) == {:error, :no_elements}
  end

  test "refuses tags that are not SVG shapes" do
    assert Converter.to_svg(~S|[["script", { src: "x.js" }]]|) == {:error, {:unknown_tag, "script"}}

    assert Converter.to_svg(~S|[["path", { d: "M0 0" }], ["foreignObject", {}]]|) ==
             {:error, {:unknown_tag, "foreignObject"}}
  end

  test "ignores attribute names that are not identifiers" do
    assert Converter.to_svg(~S|[["path", { "on-click": "x", d: "M0 0" }]]|) == {:ok, ~s(<path d="M0 0"/>)}
  end
end
