# V build tools

Development setup, production builds, compiler adapters, memory supervision,
source verification, and Git hooks run in V. Python is not needed for these
commands. Existing Python tests, benchmarks, and generators remain available.

Use current V with its matching vlib. `V_BIN` selects the compiler; otherwise
the shell bootstrap finds `v` on PATH, then `$HOME/code/v/v`. Compiler probes
reject a mismatched runtime and disable fallback to the compatibility compiler.

```sh
# Prepare native dependencies and the environment for plain v . builds.
eval "$(sh tools/run_v_tool.sh dev_build_env)"
v .

# Managed production build; preserves the shared queue and publication lease.
sh build-prod-browser.sh --prod

# Install or upgrade the managed hooks without replacing custom hooks.
sh tools/run_v_tool.sh rebuild_browser --install-hook

# Bound a focused check to 3 GiB of sampled process-tree RSS.
sh tools/run_v_tool.sh run_memory_bounded --limit-gib 3 \
  --lock Build/check.lock --report Build/check.json -- v -memory-limit 10G test libjs
```

Each command also has a `.vsh` entry point, for example
`v -b c -memory-limit 10G run tools/prepare_http_compat.vsh "$V_BIN"`.
`tools/run_v_tool.sh` handles compiler discovery and clears inherited VFLAGS
while compiling the tool. It forwards arguments literally.

The implementations share `tools/buildtools/`; the entry points contain no
Python bridge. Embedded JSON files contain the existing adapter replacements,
including native shader fragments, and are ordinary build inputs. Compatibility
patches still reject unknown upstream source shapes. V sources and native
libraries in the compiler checkout are not edited.

The supervisor retains coalesced requests, the default 12 GiB aggregate RSS
budget, PID/start-time checks for adopted processes, compiler-source manifests,
sealed C/linker inputs, atomic bundle exchange, reader leases, smoke checks, and
failed-build receipts. The protocol change lets an older worker finish and hand
off through the same queue and locks. Memory sampling and `lsof` pruning use
POSIX host utilities on macOS/Linux. Windows development/cross-build helpers
also have V entry points; native Windows validation requires a Windows host.

The command arguments are unchanged from their Python counterparts:

| Tool | Arguments |
| --- | --- |
| `rebuild_browser` | One of `--build`, `--request`, `--worker`, `--install-hook`, `--upgrade-worker`, `--worker-after-current`; build options `--prod`, `--backend c\|fastc`, `--no-parallel-cc` or `--parallel-cc` |
| `run_memory_bounded` | `--report PATH`, optional `--lock`, `--limit-gib`, `--timeout`, `--interval`, `--adopt-pids-from`; then `-- COMMAND...` |
| `prepare_ui2`, `prepare_http_compat`, `prepare_font_runtime`, `prepare_linux_modules`, `prepare_v_match_scope` | V compiler path |
| `prepare_prealloc_runtime` | V compiler path, optional runtime cache path |
| `build_harfbuzz` | Optional `--check-executable PATH` |
| `build_native_avif` | `--output PATH`, optional `--sdk-root PATH`, `--sanitize` |
| `build_linux_native` | Optional `--os linux\|windows` |
| `build_windows_browser` | `--javascriptcore-dll PATH --output PATH`, optional `--deps-root PATH`, `--console` |
| `dev_build_env` | Optional `--compiler`, `--javascriptcore-dll`, `--shell sh\|powershell` |
| `production_source_manifest` | `begin`, `compile`, or `combine`; `--root`, `--inventory`; compile accepts `--component-dir`, `--command COMMAND...`; combine accepts repeated `--component`, `--output`, `--parsed` |
| `freeze_browser_compile` | `--root`, `--stage`, `--receipt`, `--source`, `--flags`, `--output`; optional `--source-manifest`, `--source-inventory`, repeated `--parsed-component` |
| `parallel_browser_compile` | `--receipt PATH --output PATH -- V_COMPILER ... INPUT` |
| `localize_bundle_rpaths` | Executable path, build directory |
| `prune_build` | Optional `--idle-hours`, `--dry-run`, `--verbose` |

Python implementations are retained for the existing regression tests and
optional tooling. The default build entry points and installed hooks use V.
The migration checks compare actual staged source bytes against those reference
implementations and put failing Python executables first on PATH for V helper
invocations. To run them, compile the dispatcher once and use the memory guard:

```sh
v -b c -memory-limit 10G test tools/buildtools
v -skip-running -b c -memory-limit 10G -o /tmp/vox-build-tools tools/build_tools.vsh
VOX_BUILD_TOOLS_EXE=/tmp/vox-build-tools python3 tools/build_tools_migration_test.py
```

`VOX_BUILD_TOOLS_CACHE_ROOT` isolates adapter output for focused tests. Production
workers strip this diagnostic override. Historical benchmark receipts and reports
keep their original command lines.

## Migration validation (2026-11-12)

Validation used `/Users/alex/code/v/v3` with its matching `/Users/alex/code/v/vlib`:
19 focused V checks; 103 existing Python regression tests passed, with two
host-specific tests skipped; nine migration checks passed. The latter compare
HTTP, Brotli, UI2/Metal, Linux adapters, font initialization, preallocation and
compiler-scope output, verify compiler refusal/failure handling, reject modified
runtime files, and check child `--help` forwarding through the memory guard. Windows dependency
notices are checked with mocked compiler/import tools to keep setup stdout
usable as a shell environment. Additional V
checks cover receipt retention, safe symlink removal, and lock descriptors
closing across exec. Scratch pruning reports protected entries individually
and continues without recursive permission-error floods.

HarfBuzz and AVIF built successfully with Python commands blocked on PATH. The
unified build entry point also ran its real help flow with Python blocked.
Focused checks ran under the 3 GiB guard; HarfBuzz used the default 12 GiB guard.
The existing shared `/Users/alex/code/v/v` fails the compiler/runtime compatibility
probe; that rejection was retained. No Windows host build or new complete browser
build is claimed by these focused checks. Commits request the normal coalesced
production rebuild; a prior completed browser does not validate new tool code.
