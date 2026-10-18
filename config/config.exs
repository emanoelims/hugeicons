import Config

# The library's own builds (dev, test, docs, Dialyzer) read the fixture icons, so
# they never need the network or a license key. Host applications configure their
# own styles; this file is not part of the Hex package.
config :hugeicons,
  source: {:path, "test/fixtures/icons"},
  styles: ["stroke-rounded", "solid-rounded"]
