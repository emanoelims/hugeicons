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
included, comes from the Pro registry. Each compiled style adds about 8 MB to the
running application, so list only the ones you use.

The key is only needed at compile time and is only sent to `npm.hugeicons.com`.
In CI, expose it as a secret; in Docker, use a BuildKit secret rather than a build
argument, which would stay in the image layers:

```dockerfile
RUN --mount=type=secret,id=hugeicons,env=HUGEICONS_LICENSE_KEY mix compile
```

Run `mix hugeicons.install` to download the configured styles again, for example
after a new Hugeicons release.

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

Global attributes (`class`, `id`, `aria-*`, `data-*`, `phx-*`, `fill`, `stroke`, …)
go to the `<svg>`. Icons are `aria-hidden` by default; to give one an accessible
name:

```heex
<.hugeicons_icon icon="Cancel01Icon" aria-hidden="false" role="img">
  <title>Close</title>
</.hugeicons_icon>
```

A literal icon name that does not exist warns at compile time. A name computed at
runtime (`icon={@item.icon}`) raises with a suggestion when it does not exist; use
`Hugeicons.names/0` to validate names that come from data.

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
