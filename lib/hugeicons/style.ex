defmodule Hugeicons.Style do
  @moduledoc """
  The Hugeicons styles and the npm package each one is downloaded from.

  `stroke-rounded` is the free style, published as `@hugeicons/core-free-icons`
  on the public npm registry. Every style, `stroke-rounded` included, also exists
  as a Pro package (`@hugeicons-pro/core-<style>`) on Hugeicons' private registry,
  which needs a license key.
  """

  @typedoc ~s(A Hugeicons style, such as `"stroke-rounded"` or `"solid-sharp"`.)
  @type t() :: String.t()

  @typedoc "Which registry a style comes from: the public free package or the Pro one."
  @type tier() :: :free | :pro

  @free "stroke-rounded"
  @all ~w(stroke-rounded stroke-sharp stroke-standard solid-rounded solid-sharp solid-standard
          bulk-rounded duotone-rounded twotone-rounded)

  @doc """
  Lists every style Hugeicons publishes.

      iex> "solid-sharp" in Hugeicons.Style.all()
      true
  """
  @spec all() :: [t()]
  def all, do: @all

  @doc """
  Returns the style available without a license key.

      iex> Hugeicons.Style.free()
      "stroke-rounded"
  """
  @spec free() :: t()
  def free, do: @free

  @doc """
  Returns the npm package of `style` for the given tier.

      iex> Hugeicons.Style.package("stroke-rounded", :free)
      "@hugeicons/core-free-icons"

      iex> Hugeicons.Style.package("solid-sharp", :pro)
      "@hugeicons-pro/core-solid-sharp"
  """
  @spec package(t(), tier()) :: String.t()
  def package(@free, :free), do: "@hugeicons/core-free-icons"
  def package(style, :pro) when style in @all, do: "@hugeicons-pro/core-" <> style
end
