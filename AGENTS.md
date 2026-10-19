# Hugeicons

An Elixir library: Hugeicons as a Phoenix function component (`<.hugeicons_icon>`).
Icons are downloaded from Hugeicons' npm packages when the host project compiles;
the library itself ships only code. Design and measurements:
`docs/superpowers/specs/2026-10-18-hugeicons-design.md`.

## Project guidelines

- Run `mise run precommit` (`mix precommit`) when you are done with all changes and fix any pending issues
- Follow `CONTRIBUTING.md`: Conventional Commits for commit subjects and PR titles, user-facing changes recorded under `[Unreleased]` in `CHANGELOG.md`, and new environment variables added to `mise.local.toml.example`. Never commit secrets or `mise.local.toml`
- Keep workflow Actions pinned to full commit SHAs and use least required permissions. Preserve the required check names `Conventions` and `Elixir checks` unless the repository's branch rules are updated alongside them
- Pending work, improvements and open questions live in the GitHub issues; check them before starting and open one for anything found and left for later
- Code, identifiers, docs and developer-facing messages are English

## Library rules

- **Never commit Hugeicons Pro icons** in any form (SVG, converted markup, cache files, fixtures, screenshots, docs, benchmarks). Fixtures are free icons (MIT, with `LICENSE.md`) or synthetic shapes marked as such. Docs and examples show only free icons
- The license key comes only from `HUGEICONS_LICENSE_KEY`, read in `Hugeicons.Config.new!/1`; never from config files, never stored in the cache, never in an error message or log. `Hugeicons.Config` derives `Inspect` without it. The key is sent only as the bearer token of HTTPS requests to the Pro registry's host: `Hugeicons.Fetcher` refuses a tarball URL on any other host or scheme before requesting it, and verifies every tarball against the registry's `integrity` (or `shasum`) before unpacking
- Package data is untrusted input that becomes HEEx template source: `Hugeicons.Converter` accepts only the SVG shape tags in its allowlist and identifier attribute names, and HTML-escapes every value (which neutralizes `<%` and other template syntax). Keep it that way when the converter changes
- Everything that downloads, reads the cache or reads `Mix` runs at compile time only (`Hugeicons.Cache`, `Hugeicons.Fetcher`, `Hugeicons.Config.compile_env/0`). Runtime code (`Hugeicons`, `Hugeicons.Chunk`) only dispatches to compiled clauses. Downloads start `:req` themselves because no application is running at compile time
- Read configuration with `Hugeicons.Config.compile_env/0` in the module body that needs it, so Mix tracks the keys there and recompiles that module when they change. Modules that compile icons add the cache files they read as `@external_resource`, so `mix hugeicons.install` triggers a recompile
- Icons live in 16 chunk modules (`lib/hugeicons/chunks/c00.ex`…`c15.ex`, one per file so Mix compiles them in parallel), assigned by `:erlang.phash2(name, 16)`. Changing the count means adding or removing those files and updating `Hugeicons.Chunk`. A single module holding every icon compiles about ten times slower
- Each icon clause returns a `~H` template with **only static parts**: the paths are LiveView statics, sent once per fingerprint and shared by every list item. Never move package data into a dynamic expression or an assign. Dynamic attributes (`size`, `color`, `stroke-width`, globals) belong to the single wrapper template in `Hugeicons.hugeicons_icon/1`
- `test/hugeicons/diff_test.exs` guards the payload promises (paths sent once in a list, never resent when only an attribute changes); it uses `Phoenix.LiveView.Diff`, an internal API, so adapt it when LiveView changes rather than deleting it
- The cache (`_build/hugeicons/<style>.etf`) is written atomically under a `:global` lock, because the chunk modules compile in parallel and ask for the same style at once. A cached style is reused only when its origin (`:free`, `:pro`) matches the current configuration
- The library's own builds use `config :hugeicons, source: {:path, "test/fixtures/icons"}` (`config/config.exs`), so dev, test, docs and Dialyzer never touch the network. Tests that exercise downloads stub the registries with `Req.Test` through `Hugeicons.RegistryStub`. `test/test_helper.exs` deletes `HUGEICONS_LICENSE_KEY` so the regular suite never sees a developer's key; the opt-in `:pro` suite (`mix test --only pro`) reads it from a persistent term, downloads every Pro style into its tmp dir and deletes it. Never paste its output icon markup anywhere
- Cold builds are dominated by the registry download, whose speed varies a lot over time (unpacking and converting a 36 MB tarball takes ~1.2 s). Measure with several rounds against `curl` before changing the HTTP client

## Function component and HEEx rules

These come from LiveView's source and from measuring diffs; see the design spec.

- Keep derived values inside template expressions (`{inner!(@icon, @variant)}`), not in assigns: HEEx re-runs an expression only when the assigns it reads change, while `assign/3` of a derived value inside a function component marks it changed on every render (measured: 20 KB resent for a 50-row list when only `size` changed)
- `assign_new/3` only runs when the key is absent; an `attr` with `default:` is always present, so `assign_new` never fires for it. Use it only for fallbacks of attrs declared without a default (`alt_variant` falls back to `variant`)
- A component called only with literal attributes is not re-run when the parent re-renders
- Inside `~H`, `@name` is always an assign, never a module attribute: call a function to reach module data
- `~H` requires an `assigns` variable in scope even without dynamic parts; in macro-generated code use `var!(assigns)` because of hygiene
- `attr ... values:` gives compile-time warnings for literal values, but its list is printed in the generated docs: use `doc: false` or a short `doc:` for long lists
- Do not name an attr `style`: it would shadow the global HTML `style` attribute (hence `variant`)
- `attr :rest, :global, default:` is merged key by key with what the caller passes (`Map.merge(default, given)`), so callers override single defaults such as `aria-hidden`
- In HEEx text content, `{cond && "text"}` renders `false` when `cond` is false; use `{if cond, do: "text"}`

## Official Elixir anti-patterns

- Follow the [official anti-pattern guidance](https://elixir.hexdocs.pm/what-anti-patterns.md) when implementing and reviewing changes. Read the relevant category: [code](https://elixir.hexdocs.pm/code-anti-patterns.md), [design](https://elixir.hexdocs.pm/design-anti-patterns.md), [processes](https://elixir.hexdocs.pm/process-anti-patterns.md), or [metaprogramming](https://elixir.hexdocs.pm/macro-anti-patterns.md).
- Apply the guidance in context, including its documented exceptions. An anti-pattern is a signal to investigate, not an automatic requirement to rewrite existing code. Keep refactoring within the requested scope.
- Make input shapes, required map keys, and return contracts explicit. Prefer pattern matching and guards for internal invariants, deliberate optional-key access, and boolean operators for boolean contracts. Validate external input at boundaries and handle expected failures explicitly.
- Keep error handling close to its source; avoid ambiguous `with` error translations, catch-all branches that hide unexpected results, and exceptions used for routine control flow. Preserve intentional bang APIs.
- Prefer functions to unnecessary macros; keep generated code small and compile-time dependencies explicit and tracked. This library generates code on purpose (the chunk modules); keep that generation in `Hugeicons.Chunk.__using__/1` and investigate compile time and memory before changing it.
- During code review, explain the affected contract, reachable failure, or concrete maintenance cost. Keep optional design suggestions separate from correctness findings; Credo and Dialyzer do not replace this contextual review.

## Library guidelines

- Follow the [official library guidelines](https://hexdocs.pm/elixir/library-guidelines.html): no application config read at runtime by default, no global state, minimal dependencies
- Use `Req` for HTTP (already a dependency); avoid `:httpoison`, `:tesla` and raw `:httpc`
- Public modules have `@moduledoc`, public functions `@doc` and `@spec` (Doctor enforces it); internal modules use `@moduledoc false`
- Raise `Hugeicons.Error` for download, verification and conversion failures, and `ArgumentError` for invalid configuration or component input, with messages that say what to change

## Elixir guidelines

- Elixir lists **do not support index based access via the access syntax**

  **Never do this (invalid)**:

      i = 0
      mylist = ["blue", "green"]
      mylist[i]

  Instead, **always** use `Enum.at`, pattern matching, or `List` for index based list access, ie:

      i = 0
      mylist = ["blue", "green"]
      Enum.at(mylist, i)

- Elixir variables are immutable, but can be rebound, so for block expressions like `if`, `case`, `cond`, etc
  you *must* bind the result of the expression to a variable if you want to use it and you CANNOT rebind the result inside the expression, ie:

      # INVALID: we are rebinding inside the `if` and the result never gets assigned
      if connected?(socket) do
        socket = assign(socket, :val, val)
      end

      # VALID: we rebind the result of the `if` to a new variable
      socket =
        if connected?(socket) do
          assign(socket, :val, val)
        end

- **Never** nest multiple modules in the same file as it can cause cyclic dependencies and compilation errors
- **Never** use map access syntax (`changeset[:field]`) on structs as they do not implement the Access behaviour by default. For regular structs, you **must** access the fields directly, such as `my_struct.field` or use higher level APIs that are available on the struct if they exist, `Ecto.Changeset.get_field/2` for changesets
- Elixir's standard library has everything necessary for date and time manipulation. Familiarize yourself with the common `Time`, `Date`, `DateTime`, and `Calendar` interfaces by accessing their documentation as necessary. **Never** install additional dependencies unless asked or for date/time parsing (which you can use the `date_time_parser` package)
- Don't use `String.to_atom/1` on user input (memory leak risk)
- Predicate function names should not start with `is_` and should end in a question mark. Names like `is_thing` should be reserved for guards
- Elixir's builtin OTP primitives like `DynamicSupervisor` and `Registry`, require names in the child spec, such as `{DynamicSupervisor, name: MyApp.MyDynamicSup}`, then you can use `DynamicSupervisor.start_child(MyApp.MyDynamicSup, child_spec)`
- Use `Task.async_stream(collection, callback, options)` for concurrent enumeration with back-pressure. The majority of times you will want to pass `timeout: :infinity` as option

## Mix guidelines

- Read the docs and options before using tasks (by using `mix help task_name`)
- To debug test failures, run tests in a specific file with `mix test test/my_test.exs` or run all previously failed tests with `mix test --failed`
- `mix deps.clean --all` is **almost never needed**. **Avoid** using it unless you have good reason

## Test guidelines

- **Always use `start_supervised!/1`** to start processes in tests as it guarantees cleanup between tests
- **Avoid** `Process.sleep/1` and `Process.alive?/1` in tests
  - Instead of sleeping to wait for a process to finish, **always** use `Process.monitor/1` and assert on the DOWN message:

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}

   - Instead of sleeping to synchronize before the next call, **always** use `_ = :sys.get_state/1` to ensure the process has handled prior messages

