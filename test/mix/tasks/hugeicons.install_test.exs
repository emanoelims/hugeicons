defmodule Mix.Tasks.Hugeicons.InstallTest do
  use ExUnit.Case, async: false

  alias Mix.Tasks.Hugeicons.Install

  test "reads every configured style again and reports it" do
    previous = Mix.shell()
    Mix.shell(Mix.Shell.Process)
    on_exit(fn -> Mix.shell(previous) end)

    assert Install.run([]) == :ok

    assert_received {:mix_shell, :info, ["stroke-rounded: 6 icons (test/fixtures/icons path)"]}
    assert_received {:mix_shell, :info, ["solid-rounded: 2 icons (test/fixtures/icons path)"]}
  end
end
