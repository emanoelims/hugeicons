defmodule Demo.IconsTest do
  use ExUnit.Case, async: true

  alias Demo.Icons

  doctest Icons

  describe "free icons only" do
    test "compiles only the free stroke-rounded style" do
      assert Hugeicons.variants() == ["stroke-rounded"]
    end

    test "the cached icons came from the public npm package, not the Pro registry" do
      cache =
        Path.join([Path.dirname(Mix.Project.build_path()), "hugeicons", "stroke-rounded.etf"])

      assert %{origin: :free} = cache |> File.read!() |> :erlang.binary_to_term()
    end
  end

  describe "search/1" do
    test "returns every icon for a blank query" do
      assert Icons.search("") == Hugeicons.names()
      assert Icons.search("  ") == Hugeicons.names()
      assert Icons.count() == length(Hugeicons.names())
    end

    test "matches every word, ignoring case and separators" do
      results = Icons.search("Arrow-RIGHT")

      assert "ArrowRight01Icon" in results

      assert Enum.all?(
               results,
               &(String.downcase(&1) =~ "arrow" and String.downcase(&1) =~ "right")
             )
    end

    test "matches full icon names" do
      assert "Home01Icon" in Icons.search("Home01Icon")
    end

    test "lists names that start with the first word first" do
      results = Icons.search("home")
      {starting, rest} = Enum.split_while(results, &String.starts_with?(&1, "Home"))

      assert starting != []
      assert rest != []
      refute Enum.any?(rest, &String.starts_with?(&1, "Home"))
      assert starting == Enum.sort(starting)
    end

    test "returns nothing when no name matches" do
      assert Icons.search("no such icon zzz") == []
    end
  end
end
