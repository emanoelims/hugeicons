defmodule Hugeicons.ConfigTest do
  # Not async: it changes HUGEICONS_LICENSE_KEY.
  use ExUnit.Case, async: false

  alias Hugeicons.Config

  doctest Config

  setup do
    previous = System.get_env("HUGEICONS_LICENSE_KEY")

    on_exit(fn ->
      if previous, do: System.put_env("HUGEICONS_LICENSE_KEY", previous), else: System.delete_env("HUGEICONS_LICENSE_KEY")
    end)

    System.delete_env("HUGEICONS_LICENSE_KEY")
  end

  test "defaults to the free style from npm" do
    assert %Config{styles: ["stroke-rounded"], default_variant: "stroke-rounded", source: :npm, license_key: nil} =
             Config.new!([])
  end

  test "the default variant is the first style unless given" do
    assert Config.new!(styles: ["solid-sharp", "stroke-rounded"]).default_variant == "solid-sharp"

    assert Config.new!(styles: ["solid-sharp", "stroke-rounded"], default_variant: "stroke-rounded").default_variant ==
             "stroke-rounded"
  end

  test "rejects unknown styles, a default outside the styles and bad sources" do
    assert_raise ArgumentError, ~r/unknown Hugeicons styles \["solid-round"\]/, fn ->
      Config.new!(styles: ["solid-round"])
    end

    assert_raise ArgumentError, ~r/non-empty list/, fn -> Config.new!(styles: "stroke-rounded") end
    assert_raise ArgumentError, ~r/:default_variant/, fn -> Config.new!(default_variant: "solid-sharp") end
    assert_raise ArgumentError, ~r/:source/, fn -> Config.new!(source: "test/fixtures") end
  end

  test "reads the license key from the environment and never shows it" do
    System.put_env("HUGEICONS_LICENSE_KEY", " secret-key \n")
    config = Config.new!([])

    assert config.license_key == "secret-key"
    refute inspect(config) =~ "secret-key"
  end

  test "an empty license key counts as none" do
    System.put_env("HUGEICONS_LICENSE_KEY", "")
    assert Config.new!([]).license_key == nil
  end
end
