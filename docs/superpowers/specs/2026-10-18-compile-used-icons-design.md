# Compiling only the icons a project uses — design

Date: 2026-10-18. Status: proposal, not implemented. Refs #6.

## Problem

Every configured style compiles all of its 6,067 icons into the 16 chunk modules.
The main design spec reports 6.6 to 19 MB of ebin per style; a project that uses
50 icons in two styles still carries every icon of both. This document looks at
how the library could compile only the names a project uses, what that does to
recompilation, and what it would actually save. It measures with the free icons
only (no license key) and ends with a recommendation and open questions.

The full set stays the default whatever is chosen (#6).

## What the icons cost today

Prototype: a scratch copy of the library (not committed) with a `:icons` option
that keeps only the listed names (`Map.take/2` on each icon set returned by
`Hugeicons.Cache.load!/1`, so `Hugeicons` and the chunk modules see the same
subset; see the appendix). A scratch Phoenix host depends on it with the free
`stroke-rounded` style downloaded from npm (4.3.5) and a warm
`_build/hugeicons` cache, and lists N icons sampled evenly across the
alphabet. Elixir 1.20.4 / OTP 29, phoenix_live_view 1.2.12, 10 cores.

### Size

Measured over `_build/dev/lib/hugeicons/ebin` (all of the library's modules, so
the N = 3 row is the fixed part). "Stripped" is the same files after
`:beam_lib.strip_files/1`, which is what `mix release` ships by default
(`strip_beams: true`). "Loaded" is the growth of `:erlang.memory(:code)` after
loading `Hugeicons` and the 16 chunk modules, which is what a release running in
embedded mode pays at boot. Sizes in MiB, like the main spec's 9.2 MB figure.

| Icons | ebin | Stripped (release) | Loaded code |
|---|---|---|---|
| 3 | 0.14 | 0.03 | 0.05 |
| 50 | 0.23 | 0.05 | 0.13 |
| 499 | 0.92 | 0.22 | 0.39 |
| 1,999 | 3.19 | 0.75 | 1.28 |
| 6,067 (all) | 9.19 | 2.04 | 3.83 |

So the "7 to 19 MB" in the README and the spec is the size of the dev ebin,
debug info included. What a release ships for a style is about 22% of it, and
what it holds in memory is about 42%. Applied to the Pro table of the main spec,
which is an extrapolation and was not measured: the largest styles
(solid-rounded, bulk-rounded, 19 MB of ebin each) come to about 4.2 MB in a
release and 8 MB of loaded code, and all nine Pro styles together to about
23 MB in a release and 44 MB of loaded code. A 50-icon allowlist brings
a style down to about 0.1 MB of loaded code.

### Compile time

`mix compile.elixir` time of the hugeicons dependency (`mix deps.compile
hugeicons --force` with `MIX_DEBUG=1`), 7 rounds each. The machine was shared
with other builds (load average 12 to 22 on 10 cores), so the minimum is the most
reliable figure; an earlier set of rounds at load 30 gave the same order.

| Icons | Min | Median |
|---|---|---|
| 3 | 0.62 s | 0.82 s |
| 50 | 0.66 s | 1.14 s |
| 499 | 0.81 s | 1.33 s |
| 1,999 | 0.85 s | 1.28 s |
| 6,067 (all) | 1.51 s | 1.90 s |

About 0.6 s is fixed: the library's own modules, and each of the 17 icon modules
decoding the 1.6 MB cache file. The full style adds about 0.9 s over that. A
subset saves under a second per style on a full build; with several Pro styles
the saving grows with the number of styles, but compile time is not the main
argument. Memory and release size are.

## Collecting the names

Four ways were looked at. They differ in what they can see and, above all, in
when the names are known relative to when the chunk modules compile.

### 1. An explicit allowlist in config

```elixir
# config/config.exs
config :hugeicons, icons: ~w(Home01Icon Cancel01Icon FavouriteIcon)
```

The names are known before anything compiles, read with
`Application.compile_env/3` like `:styles`. The existing `attr :icon, values:`
check keeps the list honest: a literal that is not listed warns at compile time
with file and line (verified in the prototype, both for `<.hugeicons_icon>` and
`<Hugeicons.hugeicons_icon>`). Dynamic names that are not listed raise at
runtime, as unknown names do today. Cost: someone maintains the list.

### 2. Scanning the sources for literal names

Like Tailwind finds class names: read the project's source files and keep every
token that looks like an icon name and is a known icon. The prototype scan
(`~r/\b[A-Z][A-Za-z0-9]*Icon\b/` over `.ex`, `.exs`, `.heex` and other template
files, intersected with the downloaded names) read 423 files (3.7 MB) in 0.24 s.

Its strength is that it does not care where the literal is: it also finds names
in `icon={@item.icon}` cases where the items are defined in code, such as
`%{label: "Home", icon: "Home01Icon"}` in a navigation list, which no
compile-time hook sees. False positives only compile a few extra icons (the scan
of the dependencies found `HugeiconsIcon` in documentation, which is a real icon
name). False negatives are names built at runtime (`"Home0#{n}Icon"`) or stored
in a database; those still need the allowlist.

The open part is where the scan runs (see Recompilation): inside the dependency
it would have to guess the host's root and source directories.

### 3. A compile tracer

A tracer is set by the host (`elixirc_options: [tracers: [...]]`); a dependency
cannot install one. Tested in the prototype:

- the call events (`{:imported_function | :remote_function, meta, Hugeicons,
  :hugeicons_icon, 1}`) say which modules call the component, never with which
  arguments, so they cannot give names on their own;
- in the `{:on_module, bytecode, _}` event the module's attributes can still be
  read, and LiveView's private `__components_calls__` attribute holds every HEEx
  component call with its literal attributes: `{8, 22, {:string,
  "Home01Icon"}}` for a literal, `{10, 22, :any}` for `icon={@item_icon}`.

So a tracer can collect the literal names of HEEx calls, but only through a
LiveView internal that can change in any release, only for HEEx tags (not
`hugeicons_icon(%{icon: ...})` from Elixir, not names held in data), and only
while the host compiles, which is after the library compiled (next section).

### 4. `@after_verify` of the callers

LiveView registers `@after_verify {__MODULE__, :__phoenix_component_verify__}`
in every module that calls a component; that callback reads
`Hugeicons.__components__()` and is what turns the `values:` list into warnings.
The library could only add its own `@after_verify` to callers by asking hosts to
`use Hugeicons` instead of `import Hugeicons`, and by the time it runs the module
is closed: its attributes are gone and the calls survive only as a literal inside
`__phoenix_component_verify__/1` (or in the debug info chunk). Reading them back
is more fragile than the tracer. Not viable, beyond the warnings it already gives.

### Dynamic names

`icon={@item.icon}` is common (menus, statuses, records holding an icon). No
compile-time hook can know these values. The options are, in order of preference:

- list them in the allowlist (combined with any automatic collection);
- the scan finds them when they are literals somewhere in the code;
- keep the full set for that project (the default).

A name that is not compiled keeps raising `ArgumentError` at runtime. With an
allowlist the message can say what to do, because the cache still has every name:
"`Home02Icon` exists but is not in `config :hugeicons, :icons`" rather than "did
you mean". `Hugeicons.names/0` returns the compiled names, so
`validate_inclusion(changeset, :icon, Hugeicons.names())` keeps rejecting names
the application cannot render.

### Summary

| | Allowlist | Source scan | Tracer | `@after_verify` |
|---|---|---|---|---|
| Names known before the library compiles | yes | yes, if it scans then | no | no |
| Finds names held in code data | if listed | yes | no | no |
| Depends on LiveView internals | no | no | yes | yes |
| Host changes needed | a config key | a config key or a compiler | `elixirc_options` | `use` instead of `import` |
| False negatives | none, it is explicit | runtime-built names | data, non-HEEx calls | same as tracer |

## Recompilation and correctness

The chunk modules live in the `:hugeicons` dependency, and Mix compiles
dependencies before the host. Everything below was measured with the prototype
as a path dependency and as a git dependency (`git:` on a local repository); a
Hex dependency is expected to behave like the git one, because Mix treats every
fetchable dependency the same way, but that was not measured.

### With an allowlist in config

- Editing the list in `config/config.exs`, or in a file it pulls in with
  `import_config`, recompiles the whole dependency (26 files) on the next `mix
  compile`, for path and git dependencies alike. `Hugeicons.names/0` then returns
  the new list.
- Mix re-checks compile-time configuration only when a config file changes. A
  list computed from an environment variable or another file is not noticed: the
  prototype then failed with "the application :hugeicons has a different value
  set for key :icons during runtime compared to compile time" until the config
  file was touched. The docs should say to write the list in config, not to
  compute it.
- In the host, modules that `import Hugeicons` (in a Phoenix app, every module
  that uses `html_helpers`) are recompiled each time the dependency is; modules
  that only call `<Hugeicons.hugeicons_icon>` are not recompiled but are verified
  again, so their warnings appear and disappear with the list. Warnings stay
  correct either way. The same mechanism applies today when `:styles` changes.
- Adding one icon to the list and running `mix compile` took 2.0 to 4.0 s in the
  scratch host (a no-op compile: 0.16 s). In a real application the time of the
  host modules that import `Hugeicons` comes on top.
- A clean build (CI, Docker) compiles the right icons in one pass, because the
  list is configuration.

### With names collected from the host's code

The names exist only after the host compiles, which is after the chunk modules
compiled. Whatever collects them (tracer, `@after_verify`, or a scan run as part
of the host's compilation) can only affect the next compilation:

- A clean build compiles once. In CI or a Docker image the first and only pass
  would lack every newly used icon and raise at runtime. That rules out any
  design where a second `mix compile` is needed to be correct.
- Writing the names to a file that the chunk modules declare as
  `@external_resource` does not help a git dependency: after changing the content
  of such a file, a path dependency recompiled its 17 icon modules, while the git
  dependency was not even entered (`mix compile.elixir` of the host ran alone).
  Mix only re-checks a dependency's sources and external resources when it is a
  path dependency.
- A scan can avoid the ordering problem only if it runs before the dependency
  compiles: inside the chunk modules' bodies (they would need the host's root,
  which a dependency can only infer from `Mix.Project.deps_path/0`, and would
  still not be recompiled when the host's files change, by the previous point),
  or in a Mix compiler that the host adds before `:elixir` and that forces
  `mix deps.compile hugeicons` when the set changes. The latter works in
  principle but recompiles a dependency from inside the host's compilation,
  including the module that runs it, and makes every scan result change a
  dependency rebuild. It is the riskiest option and is not recommended for now.

The `@external_resource` finding also affects today's code: `mix
hugeicons.install` relies on it to recompile the icons after a new download, so
for a git or Hex dependency a new Hugeicons release is not picked up until
`mix deps.compile hugeicons --force`. That is outside this design and is
reported in #23.

### Releases

- `mix release` compiles from configuration, so an allowlist gives the same
  subset in dev, CI and the release.
- `:icons` would be compile-time configuration: setting it in `runtime.exs` has
  no effect on what is compiled, and a release whose runtime value differs from
  the compiled one refuses to boot (`validate_compile_env`, on by default), as for
  `:styles`.
- Releases strip debug info by default, so the table's "Stripped" column is what
  is shipped, and run in embedded mode, which loads every module at boot: the
  "Loaded code" column is paid by every running node.

## Recommendation

**First step: an explicit allowlist, `config :hugeicons, icons: [...]`, defaulting
to `:all`.** It is small (the prototype is about ten lines), needs no Mix
internals or LiveView internals, is correct on clean builds, for every kind of
dependency and in releases, and the existing `values:` warning already keeps it
honest. Concretely:

1. Read `:icons` in `Hugeicons.Config.compile_env/0` and validate it in
   `Hugeicons.Config.new!/1` (`:all` or a non-empty list of strings).
2. Filter in one place used by both `Hugeicons` and the chunk modules, after the
   cache is loaded, so the cache keeps every icon and switching the list never
   downloads again.
3. Raise `ArgumentError` at compile time for listed names that exist in no
   configured style, with a "did you mean" suggestion, so a typo in the list
   fails the build instead of producing a runtime error later.
4. Make the runtime error for an existing but unlisted name point to the
   allowlist.
5. Document it in the README (write the list in config, not computed; dynamic
   names must be listed; the recompilation it triggers) and in the CHANGELOG, and
   correct the "7 to 19 MB" wording with the release and memory figures above.
6. Test with the fixture icons: a subset compiles only the listed names, the
   unknown-name error, and the runtime message.

**Second step, if the list proves tedious: `mix hugeicons.used`.** A task that
scans the project's sources with the method above and prints the names (or
writes them to a config file the user imports and commits), with `--check` to
fail CI when a used name is missing from the list. It keeps compilation
deterministic and the list reviewable, finds most dynamic names defined in code,
and needs no LiveView internals.

**Not now: fully automatic collection at compile time.** Tracers and
`@after_verify` see names too late for a one-pass build, depend on LiveView
internals and miss names held in data; an automatic scan needs a host compiler
that rebuilds a dependency. Revisit only if the first two steps are not enough.

## Open questions for the maintainer

1. Is the saving worth the feature? Per style it is about 2 MB of release and
   4 MB of memory for the free set, extrapolated to 4 and 8 MB for the largest
   Pro styles; it matters mostly for projects that compile several Pro styles.
2. Name and shape of the option: one `icons:` list for every style (names are
   identical across the 9 styles, per the Pro verification), or a list per style?
3. Should listed names that are not in the downloaded set raise (proposed) or
   only warn? Upstream renames would then break builds loudly.
4. Should a subset also shrink the `values:` list printed in warnings (it does
   automatically), and does that change what #9 should do?
5. Is `mix hugeicons.used` wanted, and should it write a config file or only print
   and check?
6. The README and spec quote ebin sizes (with debug info) as the cost of a style;
   should they quote the release and loaded sizes instead?
7. `mix hugeicons.install` does not recompile a git or Hex dependency (#23,
   finding above): fix it there (for example by recording the cache's version in the
   compile environment) before or independently of this work?

## Appendix: prototype

Not committed to `lib/`. The allowlist part of the prototype, on top of `main`:

```elixir
# Hugeicons.Config.compile_env/0 and new!/1 gain
icons: Application.compile_env(:hugeicons, :icons, :all)
# ...
icons: Keyword.get(opts, :icons) || :all

# Hugeicons.Cache.load!/2, when collecting each style's set
{:ok, {:ok, style, set}}, sets -> Map.put(sets, style, select(set, config.icons))

defp select(set, :all), do: set
defp select(set, names), do: %{set | icons: Map.take(set.icons, names)}
```

The tracer used to check what tracers see read
`Module.get_attribute(env.module, :__components_calls__)` in the `:on_module`
event and kept the `{:string, name}` values of the `:icon` and `:alt_icon`
attributes of `{Hugeicons, :hugeicons_icon}` calls.

Sizes were read with `:beam_lib.strip_files/1` on a copy of the ebin and with
`:erlang.memory(:code)` before and after `Code.ensure_loaded!/1` of `Hugeicons`
and `Hugeicons.Chunks.C00`…`C15`; compile times from the `Ran mix
compile.elixir in …ms` line of `MIX_DEBUG=1 mix deps.compile hugeicons --force`.
The scripts themselves belong with the other benchmark scripts (#4).
