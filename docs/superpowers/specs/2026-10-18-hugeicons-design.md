# Hugeicons for Phoenix — design

Date: 2026-10-18. Status: implemented in the first cut (0.1.0, unreleased).

## Goal

Use Hugeicons in Phoenix LiveView the way the official React, Vue, Svelte and
Angular components do (inline SVG, same props), including the Pro styles through
the user's own license key, without the library ever distributing icons.

## Licensing constraints

From the [license agreement](https://hugeicons.com/license-agreement) and the
[license FAQ](https://hugeicons.com/faq/general/license):

- Free icons (`@hugeicons/core-free-icons`) are MIT: they can be fetched or
  bundled, keeping the notice.
- Pro source files (SVG, fonts, npm packages) and license keys cannot be shared,
  published or provided to anyone without a license. Icons inside an end product
  (app bundle, HTML, compiled binary) are fine; downloadable source files are not.
- One seat per person who works with Pro icons.
- Open question: "any product that competes directly with Hugeicons". An
  unofficial wrapper that only downloads with the user's key probably is not, but
  this is to be confirmed with Hugeicons before publishing to Hex (#1).

Hence: the package holds only code; icons are downloaded into the host's
`_build` with the host's key; the repository and docs show only free icons.

## Distribution facts

- Free: public npm, `@hugeicons/core-free-icons` (4.3.5 at the time, MIT,
  13 MB tarball, ~6,000 icons).
- Pro: private registry `https://npm.hugeicons.com`, scope `@hugeicons-pro`,
  packages `core-<style>`, the Universal License Key as bearer token (as
  `.npmrc` does). Styles: stroke/solid × rounded/sharp/standard, bulk-rounded,
  duotone-rounded, twotone-rounded.
- Each icon is `dist/esm/<Name>Icon.js` exporting
  `[["path", {d: "...", stroke: "currentColor", strokeWidth: "1.5", key: "0"}], ...]`.
  The Pro format was not verified (no key at hand): #2.
- Stroke widths in the free set: 20,313 × `1.5`, about 40 deliberate others
  (`2`, `1.3`, `3`…) on details.

## Decisions

1. **Inline SVG, not CSS masks or an icon font.** The Phoenix 1.8 heroicons
   approach (Tailwind plugin + `mask-image`) was studied and rejected by the
   user: paths cannot be animated, fonts get translated by browsers and wait
   to load, and masks lose per-path rendering.
2. **API mirrors the official components**:
   `<.hugeicons_icon icon="FirstBracketIcon" />` with `variant`, `alt_icon`,
   `alt_variant`, `show_alt`, `size`, `color`, `stroke_width`,
   `absolute_stroke_width`. Names are the npm export names, so they can be
   copied from the website. `variant` instead of `style` (would shadow the
   global HTML attribute).
3. **String names with compile-time validation** via `attr :icon, values: names`:
   a literal typo warns with file and line; dynamic names work and raise with a
   "did you mean" suggestion. Chosen over one function per icon
   (`StrokeRounded.first_bracket()`), which gives autocomplete but no dynamic
   names and needs snake_case conversion.
4. **Default stroke width moved to the root `<svg>`.** The converter drops
   `stroke-width="1.5"` from elements and keeps deliberate widths; the root's
   `stroke-width` reaches the rest by inheritance. The official Vue component
   overrides every element (details included) and forces `stroke` on solid
   icons; this keeps the designer's details.
5. **Static-only template per icon, one dynamic wrapper.** See measurements.
6. **16 chunk modules, one per file**, icons assigned by `:erlang.phash2/2`
   (portable across machines and OTP releases), so Mix compiles them in parallel.
7. **Download at compile time** from npm with `Req`, cache in
   `_build/hugeicons/<style>.etf`, `:global` lock + atomic write (the chunks
   compile in parallel), `@external_resource` on the cache files, config read
   with `Application.compile_env` in the consuming modules.
8. **Key only from `HUGEICONS_LICENSE_KEY`**, sent only to the Pro registry
   host over HTTPS (tarball URL host checked before requesting), tarballs
   verified against `integrity`/`shasum`, key excluded from `inspect`.
9. **Package data is untrusted template input**: tag allowlist, identifier
   attribute names, HTML-escaped values (neutralizes `<%`).

## Measurements

All on Elixir 1.20.4 / OTP 29, phoenix_live_view 1.2.12, 10 cores, the
6,067 free icons.

### LiveView diff payload (50-row list, same icon in each row)

| Approach | Initial | Unrelated assign changes | `size` changes |
|---|---|---|---|
| A: `assign(:svg, lookup)` + `raw(@svg)` (what existing icon libraries do) | 21,984 B | 9 B | 20,811 B |
| B: lookup inside the template expression | 21,984 B | 9 B | 2,711 B |
| C: one full `~H` per icon | 4,248 B | 9 B | 2,711 B |
| D: one wrapper + static-only `~H` per icon (chosen) | 4,860 B | 9 B | 2,711 B |

A resends everything because `assign/3` inside a function component marks a key
absent from the incoming assigns as changed every time (`force_assign`). C and D
share the paths as statics across list items.

### Compile time (one style)

| | Time |
|---|---|
| Map literal (A/B) | 1.9 s |
| C in one module | 253 s |
| D in one module | 15.6 s |
| D in 10 / 40 parallel modules (script) | 2.2 s / 1.1 s |
| D in 16 chunk files, real host build, cache warm | 2.5 s |
| Same, first build including the 13 MB download | 11.6 s |

One function per icon (no HEEx) compiled in 6.0 s / 8.2 MB; the chunk ebin is
9.2 MB per style. Lookup: ~1.6 µs.

### Pro styles (verified with a real key, #2)

All 9 styles, version 4.3.4: same layout as the free package, 6,067 icons each
with identical names, only allowlisted tags, and the default stroke width `1.5`
everywhere (9 to 35 icons per style keep a deliberate other width). Bulk draws
its secondary layer as `opacity="0.4"` with `currentColor`.

| Style | Tarball | Cache | Compile (warm cache) | ebin |
|---|---|---|---|---|
| stroke-rounded | 13.7 MB | 1.6 MB | 2.8 s | 9.2 MB |
| stroke-sharp | 9.7 MB | 1.0 MB | 2.3 s | 6.6 MB |
| stroke-standard | 9.8 MB | 1.1 MB | 2.5 s | 7.2 MB |
| solid-rounded | 35.8 MB | 4.6 MB | 3.4 s | 19 MB |
| solid-sharp | 15.3 MB | 1.8 MB | 2.6 s | 8.9 MB |
| solid-standard | 22.5 MB | 2.8 MB | 2.9 s | 13 MB |
| bulk-rounded | 36.4 MB | 4.6 MB | 3.2 s | 19 MB |
| duotone-rounded | 17.5 MB | 2.2 MB | 3.2 s | 13 MB |
| twotone-rounded | 14.6 MB | 1.7 MB | 2.5 s | 9.7 MB |

Unpacking and converting a 36 MB tarball takes about 1.2 s (`:erl_tar` 0.9 s,
conversion 0.3 s). The download itself varies a lot over time for every client:
the same bulk tarball took 5 s with curl and with Req at one moment, and 15 to
80 s (once 287 s, during the 9 parallel downloads) at others. Hence parallel
downloads, progress messages and the CI/Docker caching advice; socket buffer
tuning looked promising in 3 rounds but was not adopted without more evidence.

### Function component facts (from LiveView 1.2.8 source)

- `assign_new/3` computes only when the key is absent; attrs with defaults are
  always present.
- `assign/3` skips marking when the value is identical and the key was given.
- A component call whose attributes are all literals is not re-evaluated on
  parent re-renders.
- Global attr defaults are merged key by key with the caller's.
- `attr values:` warnings come from `@after_verify`; the list is printed in the
  generated docs.

## Existing libraries studied

`heroicons` 0.5.7 (3.2 M downloads), `lucide_icons` 2.4.4, `ex_heroicons` 3.1.0:
all render paths as a dynamic `{:safe, ...}` string (approach A); heroicons also
assigns all four styles' paths on every call.

## Deferred (GitHub issues)

- #1 licensing and naming confirmation before Hex
- #2 Pro format verification with a real key
- #3 version pinning for reproducible builds
- #4 benchmark scripts in the repository
- #5 demo app with a free-icon gallery
- #6 compiling only the icons a project uses
- #7 automatic `aria-hidden`/`role` with a title
- #8 global attributes resent on every re-render
- #9 clearer compile-time feedback for unknown names
- #10 supported Elixir/LiveView range and CI matrix
- #12 rulesets and repository settings
