defmodule DemoWeb.GalleryLiveTest do
  use DemoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  doctest DemoWeb.GalleryLive

  defp icon_count(html),
    do: html |> LazyHTML.from_fragment() |> LazyHTML.query("#icons > button") |> Enum.count()

  defp update(view, params) do
    defaults = %{
      query: "",
      size: "24",
      stroke_width: "1.5",
      color: "currentColor",
      absolute_stroke_width: "false"
    }

    view |> form("#controls", Map.merge(defaults, params)) |> render_change()
  end

  test "renders the first page of icons and the examples", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/")

    first = hd(Hugeicons.names())
    total = Demo.Icons.count() |> Integer.to_string() |> String.replace(~r/\B(?=(\d{3})+$)/, ",")

    assert icon_count(html) == 120
    assert has_element?(view, "#match-count", "#{total} icons")
    assert has_element?(view, "#more")
    assert has_element?(view, ~s(#icon-#{first}[data-icon="#{first}"] svg[width="24"]))
    assert has_element?(view, "#examples svg.draw-path")
    assert has_element?(view, ~s(#titled[role="img"][aria-hidden="false"] title), "Notifications")
  end

  test "searches by name and pages through the matches", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    html = update(view, %{query: "arrow"})
    count = length(Demo.Icons.search("arrow"))
    assert count > 120
    assert icon_count(html) == 120
    assert has_element?(view, "#match-count", "icons match “arrow”")

    html = view |> element("#more") |> render_click()
    assert icon_count(html) == min(count, 240)

    html = update(view, %{query: "arrow right 01"})
    assert has_element?(view, "#icon-ArrowRight01Icon")
    assert icon_count(html) == length(Demo.Icons.search("arrow right 01"))
    refute has_element?(view, "#more")
  end

  test "shows an empty state when nothing matches", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    html = update(view, %{query: "no such icon zzz"})

    assert icon_count(html) == 0
    assert has_element?(view, "#no-results", "No icon matches “no such icon zzz”")
  end

  test "applies size, stroke width, color and absolute stroke width to every icon", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")
    update(view, %{query: "Home01Icon"})

    update(view, %{query: "Home01Icon", size: "48", stroke_width: "2", color: "#e11d48"})

    assert has_element?(
             view,
             ~s(#icon-Home01Icon svg[width="48"][height="48"][stroke-width="2.0"][color="#e11d48"])
           )

    assert has_element?(
             view,
             ~s(#icons[data-snippet-attrs=' size={48} stroke_width={2} color="#e11d48"'])
           )

    update(view, %{
      query: "Home01Icon",
      size: "48",
      stroke_width: "2",
      absolute_stroke_width: "true"
    })

    assert has_element?(view, ~s(#icon-Home01Icon svg[stroke-width="1.0"][color="currentColor"]))
  end

  test "clamps or ignores invalid control values", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    render_change(view, "update", %{
      "query" => "Home01Icon",
      "size" => "4000",
      "stroke_width" => "x",
      "color" => "url(evil)"
    })

    assert has_element?(
             view,
             ~s(#icon-Home01Icon svg[width="64"][stroke-width="1.5"][color="currentColor"])
           )
  end

  test "confirms the copied snippet with the current attributes", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")
    update(view, %{query: "Home01Icon", size: "32"})

    view |> element("#icon-Home01Icon") |> render_click()

    assert has_element?(view, "#copied", ~s(<.hugeicons_icon icon="Home01Icon" size={32} />))

    send(view.pid, {:clear_copied, make_ref()})
    assert has_element?(view, "#copied")
  end

  test "toggles the alternate icon", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, ~s(#password[type="password"]))
    assert has_element?(view, ~s(#reveal[aria-label="Show password"]))

    view |> element("#reveal") |> render_click()

    assert has_element?(view, ~s(#password[type="text"]))
    assert has_element?(view, ~s(#reveal[aria-label="Hide password"]))
  end
end
