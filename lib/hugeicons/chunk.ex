defmodule Hugeicons.Chunk do
  @moduledoc """
  Spreads the icons over modules that compile in parallel.

  Each icon becomes a clause of `inner/2` in one of 16 modules
  (`C00`…`C15` under `Hugeicons.Chunks`), chosen by a portable hash of its name. A clause
  returns a HEEx template made only of static markup, so LiveView sends an icon's
  paths once and shares them across every place and list item that renders it.

  One module per file lets Mix compile them in parallel: a single module with
  every icon compiles about ten times slower than the same icons split this way.
  """

  alias Hugeicons.Style

  @count 16
  @modules List.to_tuple(
             for i <- 0..(@count - 1), do: Module.concat(Hugeicons.Chunks, "C#{String.pad_leading("#{i}", 2, "0")}")
           )

  @doc "Returns how many chunk modules there are."
  @spec count() :: pos_integer()
  def count, do: @count

  @doc """
  Returns the chunk index of an icon name.

  `:erlang.phash2/2` gives the same result on every machine and OTP release, so an
  icon always lands in the same module.
  """
  @spec index(String.t()) :: non_neg_integer()
  def index(name) when is_binary(name), do: :erlang.phash2(name, @count)

  @doc "Returns the chunk module that holds an icon name."
  @spec module(String.t()) :: module()
  def module(name), do: elem(@modules, index(name))

  @doc """
  Returns the static template of an icon, or `nil` when the name or the variant
  was not compiled.
  """
  @spec inner(Style.t(), String.t()) :: Phoenix.LiveView.Rendered.t() | nil
  def inner(variant, name) when is_binary(variant) and is_binary(name), do: module(name).inner(variant, name)

  @doc false
  defmacro __using__(opts) do
    index = Keyword.fetch!(opts, :index)

    quote bind_quoted: [index: index] do
      import Phoenix.Component, only: [sigil_H: 2]

      require Hugeicons.Config

      config = Hugeicons.Config.compile_env()

      for {style, set} <- Hugeicons.Cache.load!(config) do
        cache = Hugeicons.Cache.path(config, style)
        if File.exists?(cache), do: @external_resource(cache)

        for {name, svg} <- set.icons, Hugeicons.Chunk.index(name) == index do
          @doc false
          def inner(unquote(style), unquote(name)) do
            # ~H needs an `assigns` variable, even for a template without dynamic parts.
            var!(assigns) = %{}
            _ = var!(assigns)
            sigil_H(<<unquote(svg)>>, [])
          end
        end
      end

      @doc false
      def inner(_variant, _name), do: nil
    end
  end
end
