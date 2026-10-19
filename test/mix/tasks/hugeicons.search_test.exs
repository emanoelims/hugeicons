defmodule Mix.Tasks.Hugeicons.SearchTest do
  use ExUnit.Case, async: false

  alias Mix.Tasks.Hugeicons.Search

  # The fixture names: AbacusIcon, Cabinet02Icon, Cancel01Icon, FavouriteIcon,
  # FirstBracketIcon and Home01Icon.

  setup do
    previous = Mix.shell()
    Mix.shell(Mix.Shell.Process)
    on_exit(fn -> Mix.shell(previous) end)
  end

  defp search(args) do
    assert Search.run(args) == :ok
    printed()
  end

  defp printed do
    receive do
      {:mix_shell, :info, [name]} -> [name | printed()]
    after
      0 -> []
    end
  end

  test "prints the names containing the term, ignoring case" do
    assert search(["BRACKET"]) == ["FirstBracketIcon"]
  end

  test "lists names starting with the term before the other names containing it" do
    assert search(["c"]) == ~w(Cabinet02Icon Cancel01Icon AbacusIcon FirstBracketIcon)
  end

  test "does not count the Icon suffix every name shares as containing the term" do
    assert Search.search(~w(AbacusIcon Contact01Icon PhoneIcon), "on", 20) == ~w(Contact01Icon PhoneIcon)
    assert Search.search(~w(AbacusIcon FirstBracketIcon), "bracketicon", 20) == ["FirstBracketIcon"]
  end

  test "ignores spaces, hyphens and underscores, so words can be passed apart" do
    assert search(["first", "bracket"]) == ["FirstBracketIcon"]
    assert search(["first-bracket"]) == ["FirstBracketIcon"]
    assert search(["first_bracket_icon"]) == ["FirstBracketIcon"]
  end

  test "follows with the closest names, so typos and other spellings find the icon" do
    assert search(["FirstBrackeIcon"]) == ["FirstBracketIcon"]
    assert search(["favorite"]) == ["FavouriteIcon"]
    assert search(["cancle"]) == ["Cancel01Icon"]
  end

  test "orders the closest names by distance and leaves unrelated names out" do
    assert search(["cabinet01"]) == ["Cabinet02Icon", "Cancel01Icon"]
    assert search(["abacus"]) == ["AbacusIcon"]
  end

  describe "search/3 on the free set's names" do
    @names ~w(CalendarFavorite01Icon ChromeIcon ElectricHome01Icon FavouriteIcon Home01Icon Home02Icon SmartHomeIcon)

    test "lists the closest names after the names containing the term" do
      assert Search.search(@names, "favorite", 20) == ["CalendarFavorite01Icon", "FavouriteIcon"]
      assert Search.search(@names, "home", 20) == ~w(Home01Icon Home02Icon ElectricHome01Icon SmartHomeIcon ChromeIcon)
    end

    test "only adds close names when the names containing the term leave room" do
      assert Search.search(@names, "home", 4) == ~w(Home01Icon Home02Icon ElectricHome01Icon SmartHomeIcon)
      assert Search.search(@names, "favorite", 1) == ["CalendarFavorite01Icon"]
    end
  end

  test "prints at most --limit names" do
    assert search(["0", "--limit", "2"]) == ["Cabinet02Icon", "Cancel01Icon"]
    assert search(["c", "-n", "3"]) == ~w(Cabinet02Icon Cancel01Icon AbacusIcon)
  end

  test "raises when no compiled name is close to the term" do
    assert_raise Mix.Error, ~s(No compiled icon name matches "zzzz"), fn -> Search.run(["zzzz"]) end
  end

  test "raises without a term" do
    assert_raise Mix.Error, ~r/Expected a search term/, fn -> Search.run([]) end
    assert_raise Mix.Error, ~r/Expected a search term/, fn -> Search.run(["--", "-"]) end
  end

  test "raises on a limit that is not positive" do
    assert_raise Mix.Error, "--limit must be a positive integer, got: 0", fn -> Search.run(["home", "--limit", "0"]) end
  end
end
