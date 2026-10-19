defmodule DemoWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use DemoWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="border-b border-base-300">
      <nav class="mx-auto flex max-w-6xl items-center gap-6 px-4 py-3 sm:px-6">
        <a href={~p"/"} class="flex items-center gap-2 font-semibold">
          <.hugeicons_icon icon="SparklesIcon" size={20} /> Hugeicons
          <span class="font-normal text-base-content/60">for Phoenix</span>
        </a>
        <ul class="ml-auto flex items-center gap-4 text-sm text-base-content/70">
          <li class="hidden sm:block">
            <a href="#gallery" class="hover:text-base-content">Gallery</a>
          </li>
          <li class="hidden sm:block">
            <a href="#examples" class="hover:text-base-content">Examples</a>
          </li>
          <li>
            <a href="https://github.com/emanoelims/hugeicons" class="hover:text-base-content">
              GitHub
            </a>
          </li>
          <li><.theme_toggle /></li>
        </ul>
      </nav>
    </header>

    <main class="mx-auto max-w-6xl px-4 py-8 sm:px-6">
      {render_slot(@inner_block)}
    </main>

    <footer class="mx-auto max-w-6xl px-4 pb-10 text-xs text-base-content/50 sm:px-6">
      Free stroke-rounded icons by <a href="https://hugeicons.com" class="underline">Hugeicons</a>
      (MIT). This demo is unofficial and not endorsed by Hugeicons.
    </footer>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title="We can't find the internet"
        phx-disconnected={
          show(".phx-client-error #client-error")
          |> JS.remove_attribute("hidden", to: ".phx-client-error #client-error")
        }
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Attempting to reconnect
        <.hugeicons_icon icon="Loading03Icon" size={12} class="ml-1 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title="Something went wrong!"
        phx-disconnected={
          show(".phx-server-error #server-error")
          |> JS.remove_attribute("hidden", to: ".phx-server-error #server-error")
        }
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Attempting to reconnect
        <.hugeicons_icon icon="Loading03Icon" size={12} class="ml-1 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 [[data-theme-source=system]_&]:!left-0 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.hugeicons_icon icon="ComputerIcon" size={16} class="opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.hugeicons_icon icon="Sun03Icon" size={16} class="opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.hugeicons_icon icon="Moon02Icon" size={16} class="opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
