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
  end

  @path "M6 3C3.58901"

  defp render(assigns, changed, state \\ nil) do
    socket = struct!(Phoenix.LiveView.Socket, assigns: %{__changed__: %{}})
    {prints, components} = state || {Diff.new_fingerprints(), Diff.new_components()}

    {diff, prints, components} =
      Diff.render(socket, Page.list(Map.put(assigns, :__changed__, changed)), prints, components)

    {JSON.encode!(diff), {prints, components}}
  end

  defp occurrences(json, text), do: json |> String.split(text) |> length() |> Kernel.-(1)

  test "an icon is a template made only of static parts" do
    %Rendered{} = inner = Hugeicons.Chunk.inner("stroke-rounded", "FirstBracketIcon")

    assert inner.dynamic.(false) == []
    assert inner.fingerprint == Hugeicons.Chunk.inner("stroke-rounded", "FirstBracketIcon").fingerprint
  end

  test "a list sends an icon's paths once" do
    {json, _state} = render(%{rows: Enum.to_list(1..20), size: 24, count: 0}, nil)

    assert occurrences(json, @path) == 1
  end

  test "changing the size or an unrelated assign does not resend the paths" do
    assigns = %{rows: Enum.to_list(1..20), size: 24, count: 0}
    {_json, state} = render(assigns, nil)

    {count_json, state} = render(%{assigns | count: 1}, %{count: true}, state)
    {size_json, _state} = render(%{assigns | size: 20}, %{size: true}, state)

    assert occurrences(count_json, @path) == 0
    assert occurrences(size_json, @path) == 0
    assert size_json =~ ~S(width=\"20\")
  end
end
