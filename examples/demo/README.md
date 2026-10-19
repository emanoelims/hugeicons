# Hugeicons demo

A Phoenix app to try `<.hugeicons_icon>` by hand. It depends on the library in
this repository (`{:hugeicons, path: "../.."}`) and is not part of the Hex
package.

- **Gallery** (`DemoWeb.GalleryLive`): searches the free icons by name and
  applies `size`, `stroke_width`, `color` and `absolute_stroke_width` live. Click
  an icon to copy its component call.
- **Examples**: `show_alt`, a path animated with CSS `stroke-dashoffset`, and an
  accessible name with `<title>`.

## Running it

From the repository root:

    mise run demo

It installs the dependencies and assets, then serves
[localhost:4310](http://localhost:4310) (the default in `config/runtime.exs`; set `PORT` to change it). The first
compilation downloads the free icons (about 13 MB) into `_build/hugeicons`.

`mise run precommit:demo` runs this app's `mix precommit` (compilation without
warnings, unused lockfile entries, formatting and tests); the root
`mise run precommit` runs it together with the library's.

## Free icons only

The demo compiles only the free `stroke-rounded` style (`config/config.exs`), and
`mix.exs` removes `HUGEICONS_LICENSE_KEY` from the environment before the library
compiles, because with a key even `stroke-rounded` comes from the Pro registry. A
test checks that the cached icons came from the public npm package. Never add a
Pro style, and never render, screenshot or deploy Pro icons with this app.
`_build` (with `_build/hugeicons`) is ignored by Git.
