# Changelog

Versions follow [SemVer](https://semver.org/). Entries are curated manually,
following [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- `<.hugeicons_icon icon="FirstBracketIcon" />` renders a Hugeicons icon as inline SVG, with the props of the official components: `variant`, `alt_icon`, `alt_variant`, `show_alt`, `size`, `color`, `stroke_width` and `absolute_stroke_width`, plus global attributes and a `<title>` inner block.
- The free `stroke-rounded` style is downloaded from npm on the first compilation; Pro styles are downloaded with your own license key from `HUGEICONS_LICENSE_KEY`. Icons are cached in `_build/hugeicons` and never shipped in the package.
- A literal icon name that does not exist warns at compile time; a name computed at runtime raises with a suggestion.
- `mix hugeicons.install` downloads the configured styles again.
- Configured styles download in parallel, and compilation reports each download with its size and duration.
- `Hugeicons.names/0` and `Hugeicons.variants/0` list what was compiled.
- `config :hugeicons, version: "4.3.4"` pins the Hugeicons package version for reproducible builds. Unset, the registry's latest release is used as before. A version that is not published fails compilation with the most recent published versions, and changing the pin downloads the styles again. The free and Pro packages are versioned separately, so the pin follows the tier in use.
