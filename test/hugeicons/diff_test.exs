defmodule Hugeicons.DiffTest do
  # Guards the payload promises of the design with LiveView's diff engine
  # (`Phoenix.LiveView.Diff` is internal; update these tests if its API changes).
  use ExUnit.Case, async: true

  alias Phoenix.LiveView.Diff
  alias Phoenix.LiveView.Rendered

  defmodule Page do
    @moduledoc false
    use Phoenix.Component

    import Hugeicons

    def list(assigns) do
      ~H"""
      <p>{@count}</p>
      <ul>
        <li :for={i <- @rows}>{i}<.hugeicons_icon icon="FirstBracketIcon" size={@size} /></li>
      </ul>
      """
    end

    def absolute(assigns) do
      ~H"""
      <p>{@count}</p>
      <ul>
        <li :for={i <- @rows}>
          {i}<.hugeicons_icon icon="FirstBracketIcon" size={@size} absolute_stroke_width />
        </li>
      </ul>
      """
    end

    def titled(assigns) do
      ~H"""
      <p>{@count}</p>
      <ul>
        <li :for={i <- @rows}>
          {i}
          <.hugeicons_icon icon="FirstBracketIcon" size={@size}>
            <title>Code</title>
          </.hugeicons_icon>
        </li>
      </ul>
      """
    end
  end

  @path "M6 3C3.58901"
  @assigns %{rows: Enum.to_list(1..20), size: 24, count: 0}

  defp render(assigns, changed, state \\ nil) do
    {diff, state} = render_diff(assigns, changed, state, &Page.list/1)
    {JSON.encode!(diff), state}
  end

  defp render_diff(assigns, changed, state, page) do
    socket = struct!(Phoenix.LiveView.Socket, assigns: %{__changed__: %{}})
    {prints, components} = state || {Diff.new_fingerprints(), Diff.new_components()}

    {diff, prints, components} =
      Diff.render(socket, page.(Map.put(assigns, :__changed__, changed)), prints, components)

    {diff, {prints, components}}
  end

  # The distinct icon diffs of the rows when only `size` changes. Keys are the
  # dynamic parts of the wrapper template: 0 width, 1 height, 2 color,
  # 3 stroke-width, 4 global attributes, 5 inner block, 6 icon.
  defp size_change_rows(page) do
    {_diff, state} = render_diff(@assigns, nil, nil, page)
    {%{1 => %{k: rows}}, _state} = render_diff(%{@assigns | size: 20}, %{size: true}, state, page)

    rows
    |> Map.delete(:kc)
    |> Enum.map(fn {_index, %{1 => icon}} -> icon end)
    |> Enum.uniq()
  end

  defp occurrences(json, text), do: json |> String.split(text) |> length() |> Kernel.-(1)

  test "an icon is a template made only of static parts" do
    %Rendered{} = inner = Hugeicons.Chunk.inner("stroke-rounded", "FirstBracketIcon")

    assert inner.dynamic.(false) == []
    assert inner.fingerprint == Hugeicons.Chunk.inner("stroke-rounded", "FirstBracketIcon").fingerprint
  end

  test "a list sends an icon's paths once" do
    {json, _state} = render(@assigns, nil)

    assert occurrences(json, @path) == 1
  end

  test "changing the size or an unrelated assign does not resend the paths" do
    {_json, state} = render(@assigns, nil)

    {count_json, state} = render(%{@assigns | count: 1}, %{count: true}, state)
    {size_json, _state} = render(%{@assigns | size: 20}, %{size: true}, state)

    assert occurrences(count_json, @path) == 0
    assert occurrences(size_json, @path) == 0
    assert size_json =~ ~S(width=\"20\")
  end

  test "an unrelated assign change sends nothing for the icons" do
    for page <- [&Page.list/1, &Page.titled/1] do
      {_diff, state} = render_diff(@assigns, nil, nil, page)

      assert {%{0 => "1"}, _state} = render_diff(%{@assigns | count: 1}, %{count: true}, state, page)
    end
  end

  test "a size change resends stroke-width only for absolute widths" do
    assert size_change_rows(&Page.list/1) == [
             %{0 => ~S( width="20"), 1 => ~S( height="20"), 4 => ~S( aria-hidden="true")}
           ]

    assert size_change_rows(&Page.absolute/1) == [
             %{0 => ~S( width="20"), 1 => ~S( height="20"), 3 => ~S( stroke-width="1.8"), 4 => ~S( aria-hidden="true")}
           ]
  end

  # `Phoenix.Component.Declarative` puts the merged global attributes in `rest` with
  # `assign/3` on every call; the key is never in the incoming assigns, so it is
  # always marked changed and `{@rest}` (here with the accessibility defaults) is
  # resent whenever the icon re-runs, even if no global attribute changed (#8).
  # Drop key 4 from these expectations if LiveView stops marking it.
  test "a size change resends the global attributes and the accessibility defaults" do
    assert size_change_rows(&Page.titled/1) == [
             %{0 => ~S( width="20"), 1 => ~S( height="20"), 4 => ~S( role="img")}
           ]
  end
end
