defmodule DemoWeb.GalleryLive do
  @moduledoc """
  A gallery of the free icons with live attribute controls, plus examples of
  `show_alt`, an animated path and an accessible name.
  """
  use DemoWeb, :live_view

  alias Demo.Icons

  # Icons rendered per page: enough to fill the screen, few enough to keep the
  # first render and every attribute change small.
  @page_size 120
  @copied_timeout 1800

  @default_size 24
  @default_stroke_width 1.5
  @colors [
    {"Current color", "currentColor"},
    {"Rose", "#e11d48"},
    {"Amber", "#d97706"},
    {"Emerald", "#059669"},
    {"Sky", "#0284c7"},
    {"Violet", "#7c3aed"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        page_title: "Gallery",
        total: Icons.count(),
        query: "",
        limit: @page_size,
        size: @default_size,
        stroke_width: @default_stroke_width,
        color: "currentColor",
        absolute: false,
        copied: nil,
        revealed: false
      )
      |> assign_results()

    {:ok, socket}
  end

  @impl true
  def handle_event("update", params, socket) do
    query = String.slice(Map.get(params, "query", ""), 0, 100)

    socket =
      socket
      |> assign(
        size: parse_size(params["size"]),
        stroke_width: parse_stroke_width(params["stroke_width"]),
        color: parse_color(params["color"]),
        absolute: params["absolute_stroke_width"] == "true"
      )
      |> search(query)

    {:noreply, socket}
  end

  def handle_event("more", _params, socket) do
    {:noreply, socket |> update(:limit, &(&1 + @page_size)) |> assign_results()}
  end

  def handle_event("copied", %{"icon" => icon}, socket) do
    ref = make_ref()
    Process.send_after(self(), {:clear_copied, ref}, @copied_timeout)
    {:noreply, assign(socket, copied: {ref, icon})}
  end

  def handle_event("toggle_reveal", _params, socket) do
    {:noreply, update(socket, :revealed, &(not &1))}
  end

  @impl true
  def handle_info({:clear_copied, ref}, socket) do
    case socket.assigns.copied do
      {^ref, _icon} -> {:noreply, assign(socket, copied: nil)}
      _newer_or_cleared -> {:noreply, socket}
    end
  end

  defp search(%{assigns: %{query: query}} = socket, query), do: socket

  defp search(socket, query),
    do: socket |> assign(query: query, limit: @page_size) |> assign_results()

  defp assign_results(%{assigns: %{query: query, limit: limit}} = socket) do
    matches = Icons.search(query)
    assign(socket, results: Enum.take(matches, limit), match_count: length(matches))
  end

  # Params come from the browser: clamp them to the ranges the controls offer.
  defp parse_size(value), do: parse(value, &Integer.parse/1, @default_size, {12, 64})

  defp parse_stroke_width(value),
    do: parse(value, &Float.parse/1, @default_stroke_width, {0.5, 3.0})

  defp parse(value, parser, default, {low, high}) when is_binary(value) do
    case parser.(value) do
      {number, ""} -> number |> max(low) |> min(high)
      _invalid -> default
    end
  end

  defp parse(_value, _parser, default, _bounds), do: default

  defp parse_color(color) do
    if Enum.any?(@colors, fn {_label, value} -> value == color end),
      do: color,
      else: "currentColor"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <section id="gallery" class="space-y-6">
        <div class="space-y-1">
          <h1 class="text-2xl font-semibold tracking-tight">Free icons</h1>
          <p class="text-sm text-base-content/60">
            The {format_count(@total)} free <code>stroke-rounded</code>
            icons. Click one to copy its component.
          </p>
        </div>

        <form
          id="controls"
          phx-change="update"
          phx-submit="update"
          class="sticky top-0 z-10 -mx-4 flex flex-wrap items-center gap-x-6 gap-y-3 border-b border-base-300 bg-base-100/90 px-4 py-3 backdrop-blur sm:-mx-6 sm:px-6"
        >
          <label class="input input-sm w-full sm:w-72">
            <.hugeicons_icon icon="Search01Icon" size={16} class="opacity-50" />
            <input
              type="search"
              name="query"
              value={@query}
              placeholder="Search icons"
              aria-label="Search icons"
              autocomplete="off"
              phx-debounce="150"
              class="grow"
            />
          </label>

          <label class="flex items-center gap-2 text-sm">
            <span class="text-base-content/60">Size</span>
            <input
              type="range"
              name="size"
              min="12"
              max="64"
              step="2"
              value={@size}
              class="range range-xs w-24"
            />
            <span class="w-10 tabular-nums">{@size}px</span>
          </label>

          <label class="flex items-center gap-2 text-sm">
            <span class="text-base-content/60">Stroke</span>
            <input
              type="range"
              name="stroke_width"
              min="0.5"
              max="3"
              step="0.25"
              value={@stroke_width}
              class="range range-xs w-24"
            />
            <span class="w-8 tabular-nums">{format_number(@stroke_width)}</span>
          </label>

          <fieldset class="flex items-center gap-2">
            <legend class="sr-only">Color</legend>
            <label :for={{label, value} <- colors()} title={label} class="cursor-pointer">
              <input
                type="radio"
                name="color"
                value={value}
                checked={@color == value}
                class="peer sr-only"
              />
              <span class="sr-only">{label}</span>
              <span
                class="block size-4 rounded-full ring-offset-2 ring-offset-base-100 peer-checked:ring-2 peer-checked:ring-base-content/50 peer-focus-visible:outline-2"
                style={"background: #{value}"}
              />
            </label>
          </fieldset>

          <label class="flex items-center gap-2 text-sm">
            <input type="hidden" name="absolute_stroke_width" value="false" />
            <input
              type="checkbox"
              name="absolute_stroke_width"
              value="true"
              checked={@absolute}
              class="toggle toggle-xs"
            />
            <span class="text-base-content/60">Absolute stroke</span>
          </label>
        </form>

        <p id="match-count" class="text-sm text-base-content/60">
          {match_summary(@match_count, @total, @query)}
        </p>

        <div
          id="icons"
          data-snippet-attrs={snippet_attrs(@size, @stroke_width, @color, @absolute)}
          class="grid grid-cols-[repeat(auto-fill,minmax(7.5rem,1fr))] gap-2"
        >
          <button
            :for={name <- @results}
            :key={name}
            id={"icon-#{name}"}
            type="button"
            data-icon={name}
            title={"Copy #{name}"}
            phx-click={JS.dispatch("demo:copy") |> JS.push("copied", value: %{icon: name})}
            class="flex aspect-square cursor-pointer flex-col items-center justify-center gap-3 overflow-hidden rounded-box p-2 text-base-content/80 hover:bg-base-200 hover:text-base-content focus-visible:bg-base-200"
          >
            <.hugeicons_icon
              icon={name}
              size={@size}
              stroke_width={@stroke_width}
              color={@color}
              absolute_stroke_width={@absolute}
              class="pointer-events-none shrink-0"
            />
            <span class="pointer-events-none w-full truncate text-center text-xs text-base-content/60">
              {String.replace_suffix(name, "Icon", "")}
            </span>
          </button>
        </div>

        <p :if={@match_count == 0} id="no-results" class="py-16 text-center text-base-content/60">
          No icon matches “{@query}”.
        </p>

        <div :if={@match_count > length(@results)} class="flex justify-center">
          <button id="more" type="button" phx-click="more" class="btn btn-sm btn-ghost">
            Show more
          </button>
        </div>
      </section>

      <section id="examples" class="mt-16 space-y-6 border-t border-base-300 pt-10">
        <h2 class="text-xl font-semibold tracking-tight">Examples</h2>
        <div class="grid gap-4 md:grid-cols-3">
          <.example title="Alternate icon" code={show_alt_code()}>
            <div class="flex items-center gap-1">
              <input
                id="password"
                type={if @revealed, do: "text", else: "password"}
                value="hugeicons"
                readonly
                aria-label="Password"
                class="input input-sm w-36"
              />
              <button
                id="reveal"
                type="button"
                phx-click="toggle_reveal"
                aria-label={if @revealed, do: "Hide password", else: "Show password"}
                class="btn btn-sm btn-ghost btn-square"
              >
                <.hugeicons_icon icon="ViewIcon" alt_icon="ViewOffSlashIcon" show_alt={@revealed} />
              </button>
            </div>
          </.example>

          <.example title="Animated path" code={animated_code()}>
            <.hugeicons_icon icon="FavouriteIcon" size={48} class="draw-path text-rose-500" />
          </.example>

          <.example title="Accessible name" code={title_code()}>
            <.hugeicons_icon id="titled" icon="Notification01Icon" aria-hidden="false" role="img">
              <title>Notifications</title>
            </.hugeicons_icon>
          </.example>
        </div>
      </section>

      <div aria-live="polite" class="pointer-events-none fixed inset-x-0 bottom-6 flex justify-center">
        <p
          :if={@copied}
          id="copied"
          class="rounded-box bg-neutral px-4 py-2 text-sm text-neutral-content shadow-lg"
        >
          Copied <code>{snippet(elem(@copied, 1), @size, @stroke_width, @color, @absolute)}</code>
        </p>
      </div>
    </Layouts.app>
    """
  end

  attr :title, :string, required: true
  attr :code, :string, required: true
  slot :inner_block, required: true

  defp example(assigns) do
    ~H"""
    <figure class="flex flex-col overflow-hidden rounded-box border border-base-300">
      <div class="flex h-32 items-center justify-center">{render_slot(@inner_block)}</div>
      <figcaption class="border-t border-base-300 bg-base-200/50 p-4">
        <p class="mb-2 text-sm font-medium">{@title}</p>
        <pre class="overflow-x-auto text-xs leading-relaxed text-base-content/70"><code>{@code}</code></pre>
      </figcaption>
    </figure>
    """
  end

  defp colors, do: @colors

  @doc """
  Returns the component call for `icon` with the attributes that differ from
  their defaults.

      iex> DemoWeb.GalleryLive.snippet("Home01Icon", 24, 1.5, "currentColor", false)
      ~s(<.hugeicons_icon icon="Home01Icon" />)

      iex> DemoWeb.GalleryLive.snippet("Home01Icon", 32, 2.0, "#e11d48", true)
      ~s(<.hugeicons_icon icon="Home01Icon" size={32} stroke_width={2} color="#e11d48" absolute_stroke_width />)
  """
  @spec snippet(String.t(), pos_integer(), float(), String.t(), boolean()) :: String.t()
  def snippet(icon, size, stroke_width, color, absolute) do
    ~s(<.hugeicons_icon icon="#{icon}"#{snippet_attrs(size, stroke_width, color, absolute)} />)
  end

  # Rendered once on the grid; assets/js/app.js joins it with the clicked icon's
  # name, so an attribute change does not resend a snippet per icon.
  defp snippet_attrs(size, stroke_width, color, absolute) do
    [
      size != @default_size && " size={#{size}}",
      stroke_width != @default_stroke_width && " stroke_width={#{format_number(stroke_width)}}",
      color != "currentColor" && ~s( color="#{color}"),
      absolute && " absolute_stroke_width"
    ]
    |> Enum.filter(& &1)
    |> Enum.join()
  end

  defp format_number(number) when number == trunc(number), do: Integer.to_string(trunc(number))
  defp format_number(number), do: Float.to_string(number)

  defp format_count(count) do
    count |> Integer.to_string() |> String.replace(~r/\B(?=(\d{3})+$)/, ",")
  end

  defp match_summary(total, total, ""), do: "#{format_count(total)} icons"
  defp match_summary(1, _total, query), do: "1 icon matches “#{query}”"
  defp match_summary(count, _total, query), do: "#{format_count(count)} icons match “#{query}”"

  defp show_alt_code do
    ~S"""
    <.hugeicons_icon
      icon="ViewIcon"
      alt_icon="ViewOffSlashIcon"
      show_alt={@revealed}
    />
    """
  end

  defp animated_code do
    ~S"""
    <.hugeicons_icon
      icon="FavouriteIcon"
      class="draw-path"
    />

    .draw-path path {
      stroke-dasharray: 64;
      stroke-dashoffset: 64;
      animation: draw-path 2s
        ease-in-out infinite alternate;
    }
    @keyframes draw-path {
      to { stroke-dashoffset: 0; }
    }
    """
  end

  defp title_code do
    ~S"""
    <.hugeicons_icon
      icon="Notification01Icon"
      aria-hidden="false"
      role="img"
    >
      <title>Notifications</title>
    </.hugeicons_icon>
    """
  end
end
