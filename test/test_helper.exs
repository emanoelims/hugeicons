# The suite never sees a developer's license key (mise loads it from
# mise.local.toml): tests stub the registries and must not depend on, or send,
# a real key. The opt-in `:pro` integration tests read it from here instead.
:persistent_term.put({Hugeicons.ProTest, :license_key}, System.get_env("HUGEICONS_LICENSE_KEY"))
System.delete_env("HUGEICONS_LICENSE_KEY")

# Download progress goes to the Mix shell; keep it out of the test output.
Mix.shell(Mix.Shell.Process)

ExUnit.start(exclude: [:pro])
