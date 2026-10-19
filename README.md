# Hugeicons for Phoenix

Unofficial [Hugeicons](https://hugeicons.com) function components for Phoenix
LiveView, with Pro support through your own license key.

```heex
<.hugeicons_icon icon="FirstBracketIcon" />
<.hugeicons_icon icon="FirstBracketIcon" variant="solid-sharp" size={20} class="text-zinc-500" />
```

Icons render as inline SVG, like the official React, Vue, Svelte and Angular
components: every `<path>` is in the DOM, so CSS can animate it, the browser's page
translation leaves it alone, and nothing waits for a font to load.

> #### Unofficial {: .warning}
>
> This library is not made or endorsed by Hugeicons. It ships no icons: it downloads
> them from Hugeicons' own npm packages when your project compiles.

## Installation

Requires Elixir 1.20 or later and Phoenix LiveView 1.1 or 1.2. CI tests the
library against the locked LiveView 1.2 release and against 1.1.0, the lowest
supported one.

```elixir
def deps do
  [
    {:hugeicons, github: "emanoelims/hugeicons"}
  ]
end
```

Import the component in the `html_helpers` of your web module (`lib/my_app_web.ex`):

```elixir
defp html_helpers do
  quote do
    import Hugeicons, only: [hugeicons_icon: 1]
    # ...
  end
end
```

The first `mix compile` downloads the free `stroke-rounded` style (about 13 MB,
once) into `_build/hugeicons`.

## Pro styles

Set your Universal License Key (hugeicons.com → Account → Tokens) in the
`HUGEICONS_LICENSE_KEY` environment variable, for example in a gitignored
`mise.local.toml`:

```toml
[env]
HUGEICONS_LICENSE_KEY = "..."
```

and choose the styles to compile:

```elixir
# config/config.exs
config :hugeicons,
  styles: ["stroke-rounded", "solid-rounded", "bulk-rounded"],
  default_variant: "stroke-rounded"
```

Available styles: `stroke-rounded`, `stroke-sharp`, `stroke-standard`,
`solid-rounded`, `solid-sharp`, `solid-standard`, `bulk-rounded`,
`duotone-rounded` and `twotone-rounded`. With a key, every style, `stroke-rounded`
included, comes from the Pro registry. Each compiled style adds 7 to 19 MB of
code to the running application (the filled styles are the largest), so list only
the ones you use.

The key is only needed at compile time and is only sent to `npm.hugeicons.com`.
In CI, expose it as a secret; in Docker, use a BuildKit secret rather than a build
argument, which would stay in the image layers:

```dockerfile
RUN --mount=type=secret,id=hugeicons,env=HUGEICONS_LICENSE_KEY mix compile
```

Run `mix hugeicons.install` to download the configured styles again, for example
after a new Hugeicons release. It then recompiles the `:hugeicons` dependency, so
the new icons are compiled in whether it comes from Hex, git or a path.

### Cold builds

Each style is downloaded once per build directory, and the filled Pro styles are
large: expect minutes rather than seconds on a cold build (compilation prints
each download). Keep `_build/hugeicons` between builds:

- in CI, cache `_build` (or at least `_build/hugeicons`) keyed by your lockfile
  and the configured styles;
- in Docker, use a BuildKit cache mount, which also keeps the downloaded icons
  out of the image layers:

```dockerfile
RUN --mount=type=secret,id=hugeicons,env=HUGEICONS_LICENSE_KEY \
    --mount=type=cache,target=/app/_build/hugeicons \
    mix compile
```

## Pinning the version

Without a pin, each style downloads the registry's `latest` release the first time
a build directory compiles it. Two machines, or CI and a laptop, can then compile
different Hugeicons versions, and a new release can add, rename or remove icons
without any change in your repository. Pin the version for reproducible builds:

```elixir
# config/config.exs
config :hugeicons, version: "4.3.4"
```

Every configured style then downloads exactly that version, and compilation fails
with the most recent published versions when it does not exist. Changing the pin
downloads the styles again on the next `mix compile`. Without a pin, the cached
styles stay as they are until `mix hugeicons.install`, which prints the version
each style resolved to, so running it once is a way to find the version to pin.

The free and Pro packages are versioned separately (on 2026-10-18 the latest free
release was 4.3.5 and the latest Pro release 4.3.4), and the pin applies to the
tier in use: with `HUGEICONS_LICENSE_KEY` every style comes from the Pro registry,
so pin a Pro version; without it, pin a free version. Adding or removing the key
usually needs a new pin too.

Pin the version in applications that are built in CI, deployed, or developed by
more than one person, and bump it deliberately to adopt a new release. Leave it
unset to always follow the latest release, for example while trying the library.

## Usage

| Attribute | Default | |
|---|---|---|
| `icon` | required | Icon name as exported by the npm packages: `"FirstBracketIcon"` |
| `variant` | `:default_variant` | Style to render |
| `alt_icon` | `nil` | Icon shown instead when `show_alt` is true |
| `alt_variant` | `variant` | Style of `alt_icon` |
| `show_alt` | `false` | Shows `alt_icon` |
| `size` | `24` | Width and height |
| `color` | `"currentColor"` | Icon color |
| `stroke_width` | `1.5` | Width of the strokes drawn with the default width |
| `absolute_stroke_width` | `false` | Keeps the stroke width constant on screen whatever the size |

Global attributes (`class`, `id`, `aria-*`, `data-*`, `phx-*`, `stroke`, …)
go to the `<svg>`.

A literal icon name that does not exist warns at compile time. A name computed at
runtime (`icon={@item.icon}`) raises with a suggestion when it does not exist; use
`Hugeicons.names/0` to validate names that come from data.

Icon names are strings, which editors do not autocomplete. To find one from the
terminal, run `mix hugeicons.search`: it compiles your project and lists the
compiled names that contain a term, then the closest ones, so a typo or another
spelling still finds the icon:

```console
$ mix hugeicons.search first bracket
FirstBracketCircleIcon
FirstBracketIcon
FirstBracketSquareIcon
RootFirstBracketIcon
ThirdBracketIcon
```

Case, spaces, hyphens and underscores are ignored; `--limit` (default 20) caps
the list.

### Accessibility

An icon is decorative by default and renders `aria-hidden="true"`. To give one an
accessible name, pass `label`: it is rendered as the `<title>`, and the icon then
renders `role="img"` and no `aria-hidden`, so screen readers announce it.

```heex
<.hugeicons_icon icon="Cancel01Icon" label="Close" />
```

A `nil` or empty `label` keeps the icon decorative, so `label={@label}` works for a
name that may be missing. An `aria-label` or `aria-labelledby` also names the icon.
The inner block (for `<desc>`, `<animate>` and the like) never does: HEEx builds it
even when it renders nothing, so it cannot tell a name is there.

A `role` or `aria-hidden` you pass yourself always wins. Inside a button or link
that already has a text label, leave the icon decorative.

## How it works

At compile time the library downloads each style's npm package, checks it against
the registry's integrity hash, converts every icon into SVG markup and compiles it
into one of 16 modules that Mix builds in parallel. Each icon is a HEEx template
made only of static markup, so LiveView sends its paths once, shares them across
every list item that renders it, and never sends them again when only `size`,
`color` or another attribute changes.

## License

The library is [MIT](https://github.com/emanoelims/hugeicons/blob/main/LICENSE). The icons are not part of it: the free icons are
under Hugeicons' MIT license, and Pro icons are covered by your
[Hugeicons license agreement](https://hugeicons.com/license-agreement). Never
commit `_build/hugeicons` or otherwise redistribute Pro icons.

See [CONTRIBUTING.md](https://github.com/emanoelims/hugeicons/blob/main/CONTRIBUTING.md) for development and
[SECURITY.md](https://github.com/emanoelims/hugeicons/blob/main/SECURITY.md) to report vulnerabilities.
