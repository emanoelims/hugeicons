defmodule Mix.Tasks.Hugeicons.Install do
  @shortdoc "Downloads the configured Hugeicons styles again"

  @moduledoc """
  Downloads every configured style again, replacing the cached icons.

      $ mix hugeicons.install

  Icons are downloaded on the first compilation anyway; run this task to pick up a
  new Hugeicons release or after changing your plan. The modules that compiled the
  icons track the cache files, so the next `mix compile` recompiles them.

  Each style is reported with the version it resolved to: the pinned `:version`
  when one is configured, or else the registry's latest release. Without a pin,
  that is the version to set to keep builds reproducible.

  Pro styles need `HUGEICONS_LICENSE_KEY` in the environment, for example through
  `mise.local.toml`.
  """
  use Mix.Task

  alias Hugeicons.Cache
  alias Hugeicons.Config

  @requirements ["loadconfig"]

  @impl Mix.Task
  def run(args) do
    {_opts, _args} = OptionParser.parse!(args, strict: [])
    config = :hugeicons |> Application.get_all_env() |> Config.new!()

    for style <- config.styles do
      set = Cache.refresh!(config, style)
      Mix.shell().info("#{style}: #{map_size(set.icons)} icons (#{origin_label(set.origin)} #{set.version})")
    end

    :ok
  end

  defp origin_label(:free), do: "free"
  defp origin_label(:pro), do: "pro"
  defp origin_label({:path, dir}), do: Path.relative_to_cwd(dir)
end
