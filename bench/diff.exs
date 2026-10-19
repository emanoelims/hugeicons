# LiveView diff payload of a list of rows rendering the same icon.
#
#     mise exec -- elixir bench/diff.exs [--rows 50] [--icon FirstBracketIcon]
#
# Renders a list with LiveView's diff engine (Phoenix.LiveView.Diff, an internal
# API, as test/hugeicons/diff_test.exs does) and reports the JSON size sent for the
# initial render, for a change of an unrelated assign and for a change of `size`.
#
# The shipped component is compared with two reference implementations that keep
# every icon in a map literal and render the markup with raw/1:
#
#   * A: the markup is assigned (`assign(assigns, :svg, ...)`), as existing icon
#     libraries do. An assign set inside a function component is marked changed on
#     every render, so the paths are resent whenever the component re-runs.
#   * B: the lookup stays inside the template expression, so it re-runs only when
#     its inputs change; the markup is still one dynamic string per row.
#
# The design spec also measured one full `~H` per icon with the dynamic attributes
# in it (C). It is left out here: compiling ~6,000 such templates takes minutes
# (253 s in the spec), and its payload is within a few hundred bytes of the shipped
# approach.

Code.require_file("setup.exs", __DIR__)

defmodule Bench.Icons do
  @moduledoc false
  # Every icon's markup in a map literal, as approaches A and B need.
  @icons Bench.icon_set().icons

  def svg!(name), do: Map.fetch!(@icons, name)
end

defmodule Bench.Reference do
  @moduledoc false
  use Phoenix.Component

  import Phoenix.HTML, only: [raw: 1]

  # The same wrapper as Hugeicons.hugeicons_icon/1, minus variants and alt icons.
  attr :icon, :string, required: true
  attr :size, :any, default: 24
  attr :color, :string, default: "currentColor"
  attr :stroke_width, :any, default: 1.5
  attr :absolute_stroke_width, :boolean, default: false
  attr :rest, :global, default: %{"aria-hidden" => "true"}

  def assigned_icon(assigns) do
    assigns = assign(assigns, :svg, Bench.Icons.svg!(assigns.icon))

    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      width={@size}
      height={@size}
      fill="none"
      color={@color}
      stroke-width={stroke_width(@stroke_width, @absolute_stroke_width, @size)}
      {@rest}
    >{raw(@svg)}</svg>
    """
  end

  attr :icon, :string, required: true
  attr :size, :any, default: 24
  attr :color, :string, default: "currentColor"
  attr :stroke_width, :any, default: 1.5
  attr :absolute_stroke_width, :boolean, default: false
  attr :rest, :global, default: %{"aria-hidden" => "true"}

  def expression_icon(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      width={@size}
      height={@size}
      fill="none"
      color={@color}
      stroke-width={stroke_width(@stroke_width, @absolute_stroke_width, @size)}
      {@rest}
    >{raw(Bench.Icons.svg!(@icon))}</svg>
    """
  end

  defp stroke_width(width, true, size) when is_number(width) and is_number(size) and size > 0, do: width * 24 / size
  defp stroke_width(width, _absolute, _size), do: width
end

defmodule Bench.Page do
  @moduledoc false
  use Phoenix.Component

  import Bench.Reference
  import Hugeicons

  def list(%{approach: :assigned} = assigns) do
    ~H"""
    <p>{@count}</p>
    <ul>
      <li :for={i <- @rows}>{i}<.assigned_icon icon={@icon} size={@size} /></li>
    </ul>
    """
  end

  def list(%{approach: :expression} = assigns) do
    ~H"""
    <p>{@count}</p>
    <ul>
      <li :for={i <- @rows}>{i}<.expression_icon icon={@icon} size={@size} /></li>
    </ul>
    """
  end

  def list(%{approach: :shipped} = assigns) do
    ~H"""
    <p>{@count}</p>
    <ul>
      <li :for={i <- @rows}>{i}<.hugeicons_icon icon={@icon} size={@size} /></li>
    </ul>
    """
  end
end

defmodule Bench.Diff do
  @moduledoc false
  alias Phoenix.LiveView.Diff

  @approaches [
    assigned: "A: `assign(:svg, lookup)` + `raw(@svg)`",
    expression: "B: lookup inside the template expression",
    shipped: "Shipped: one wrapper + static-only `~H` per icon"
  ]

  def run(rows, icon) do
    Bench.header("LiveView diff payload (#{rows}-row list, `#{icon}` in each row)")

    results =
      for {approach, label} <- @approaches do
        assigns = %{approach: approach, icon: icon, rows: Enum.to_list(1..rows//1), size: 24, count: 0}

        {initial, state} = render(assigns, nil, nil)
        {unrelated, state} = render(%{assigns | count: 1}, %{count: true}, state)
        {size, _state} = render(%{assigns | count: 1, size: 20}, %{size: true}, state)

        [label, Bench.bytes(initial), Bench.bytes(unrelated), Bench.bytes(size)]
      end

    Bench.table(["Approach", "Initial", "Unrelated assign changes", "`size` changes"], results)
  end

  # Returns the size of the JSON a LiveView would send, and the state to diff the
  # next render against.
  defp render(assigns, changed, state) do
    socket = struct!(Phoenix.LiveView.Socket, assigns: %{__changed__: %{}})
    {prints, components} = state || {Diff.new_fingerprints(), Diff.new_components()}
    rendered = Bench.Page.list(Map.put(assigns, :__changed__, changed))
    {diff, prints, components} = Diff.render(socket, rendered, prints, components)

    {byte_size(JSON.encode!(diff)), {prints, components}}
  end
end

{opts, _args} = OptionParser.parse!(System.argv(), strict: [rows: :integer, icon: :string])

case Keyword.get(opts, :rows, 50) do
  rows when rows > 0 -> Bench.Diff.run(rows, Keyword.get(opts, :icon, "FirstBracketIcon"))
  rows -> raise ArgumentError, "expected --rows to be positive, got: #{rows}"
end
