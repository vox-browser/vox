# Full upstream WPT inventory and execution status

The full upstream checkout has been fetched. Vox is now collecting the official
manifest's testharness variants through a separate adapter described below.
**There is no completed full-suite Vox pass rate.** The earlier 3,808-case runs
and newer 6,828-case imported runs cover Ladybird's expectation cohort only.

Upstream is checked out at `/Users/alex/code/3rd/web-platform-tests`, revision
`57bbaa12ff3515848cc0b3d3791791086a563047`, with all 167,878 tracked files and
no tracked modifications. This is a shallow history checkout of the entire
working tree, with no sparse selection or missing submodules.

The [machine-readable evidence](performance/wpt-upstream-20261108.json) records
the commands, input identities, memory guards, attempts, and local raw archive.
The locally generated version-9 upstream manifest contains:

| Type | Source files | Test variants |
|---|---:|---:|
| testharness | 32,831 | 40,139 |
| reftest | 28,938 | 29,312 |
| crashtest | 2,111 | 2,111 |
| print-reftest | 448 | 448 |
| wdspec | 685 | 685 |
| aamtest | 190 | 190 |
| test262 | 53,814 | 53,814 |
| manual | 3,047 | 3,047 |
| visual | 2,714 | 2,714 |
| **All test types** | **124,778** | **132,460** |
| Support resources | 43,094 | — |

These are files and manifest variants, **not subtests or pass results**. The
upstream manifest loader independently confirms every count. Manual and visual
tests remain separate from automated execution. The seven types enabled by
upstream wptrunner contain 126,699 variants, including Test262; that inventory
does not imply that any particular browser adapter supports every type.

The imported runner finds 3,808 cases from 3,822 expectation files. Fourteen
expectations have no matching document and are skipped. Of the selected cases,
3,697 have literal URL matches in the new upstream testharness manifest. Matching
URLs do not establish identical bytes across revisions. The imported HTTP
server cannot correctly execute the entire upstream suite: it lacks Python
handlers, generated worker pages, real HTTPS, and WPT's multi-origin setup.

## Earlier official wptrunner attempts

The exact available production executable is pinned at
`843893a4a6f9e8f235b9fe36cb4184e3df6c038dbf41370f219dcecdc1581bd2`.
The executable and native-library hashes remain unchanged across both official
runner attempts. Each command runs under a 3 GiB aggregate process-tree guard,
with one worker, the full manifest, and no path filters or manifest downloads.

- `wpt run ... vox` exits **70**, reporting missing WPT host aliases. The
  machine has no WPT hostname configuration; noninteractive sudo also requires
  a password. No system resolver settings were changed.
- A separate `wpt run ... ladybird` adapter probe exits **1**, reporting
  `Missing required argument webdriver_binary`. It does not run Vox tests or
  establish a Ladybird result. That upstream adapter needs a WebDriver service;
  supplying Vox's executable path does not provide one.
- Both requested WPT report files are empty. **Zero WPT cases executed in
  these attempts.** These are setup failures, not engine assertion failures.
- An initial command omitted upstream's required `--venv` argument when using
  `--skip-venv-setup`; its exit 1 and traceback are retained separately. The
  two corrected commands above get past that mistake.

The production binary has no integrated WebDriver launch endpoint, and WPT
does not register a Vox product. The repository's `webdriver/` module exposes
portable algorithms and host callbacks; it is not connected to the running
browser's HTTP transport, DOM, script execution, windows, or capture services.
The Ladybird adapter additionally has no print-reftest or accessibility executor.
A Vox runner integration and working test-origin DNS/TLS setup are required
before a full automated run can begin. Manual and visual cases require their
own review workflow. Upstream documents the required local environment in
[running tests locally](https://web-platform-tests.org/running-tests/from-local-system.html).

A fresh, guarded production `--headless-smoke` process passes, with the same
executable hash before and after. This establishes that the available browser
launches; it does not substitute for WPT execution. All **15** runner and
inventory unit tests pass.

## Reproducing the inventory

Keep the full checkout outside Vox's `Build/` scratch directory. Generate the
official manifest locally under the memory guard:

```sh
python3 tools/run_memory_bounded.py \
  --lock Build/wpt-manifest-UNIQUE.lock \
  --report Build/wpt-manifest-UNIQUE.json -- \
  python3 /Users/alex/code/3rd/web-platform-tests/wpt \
    manifest --no-download --no-parallel \
    --tests-root /Users/alex/code/3rd/web-platform-tests \
    --path /Users/alex/.cache/vox/wpt/upstream-57bbaa12-MANIFEST.json

python3 tools/wpt_inventory.py \
  --wpt-root /Users/alex/code/3rd/web-platform-tests \
  --manifest /Users/alex/.cache/vox/wpt/upstream-57bbaa12-MANIFEST.json \
  --imported-root /Users/alex/code/3rd/ladybird/Tests/LibWeb/Text
```

The tool records manifest and checkout identity, retains every manifest type,
and leaves the subtest count unknown. Future imported-run JSON and Markdown
reports explicitly identify their subset scope. Neither inventory generation
nor successful tooling checks count as a completed upstream WPT run.

## Official-manifest testharness adapter (November 8)

Commit `4c03f4713` adds `tools/wpt_upstream_compare.py`. It selects all
**40,139 testharness variants** directly from the official manifest rather than
Ladybird expectations. Generated window and worker URLs, query bytes, metadata
timeouts and HTTPS/service-worker flags remain distinct. Every manifest blob
hash is checked against the clean pinned Git index; all 167,878 tracked files,
the manifest identity, loaded server sources, runner and executable/library
hashes are checked before and during collection. Upstream's own RoutesBuilder
serves generated pages and worker scripts. Original testharness.js and test
assertions are unchanged; testharnessreport.js supplies result collection.

The inventory selects 32,432 HTTP, 7,423 HTTPS and 284 HTTP/2 variants. HTTPS
uses a job-private CA through SSL_CERT_FILE, with no OS trust or resolver edits.
HTTP/2 is not served by this adapter: those 284 selected variants receive
explicit `UNSUPPORTED_PROTOCOL` records and cannot count as passing. WebSocket,
WebSocket-over-TLS and WebTransport services also remain unavailable. Tests
requiring them stay in the selection and retain their observed failure or
timeout. Other manifest types remain outside this adapter's execution scope;
this is **not all 132,460 WPT variants** or an integrated WebDriver endpoint.

All **32 WPT tooling tests pass** under a 3 GiB guard. Fresh processes of
production executable `8fe20c9aaaa506da42672d47f1f1ffc087fce78f44290e68f14e62d00a1b90de`
exercise original generated-window, window-global and dedicated-worker pages:
four pages pass 20 assertions. A selected HTTP/2 variant is retained as
unsupported, so that collection exits 1. A separate original HTTPS randomUUID
page passes all three assertions with strict exit 0. The original HTTPS
secure-contexts dedicated-worker probe reaches its document and harness but
times out; its exit 1 is retained. These are focused adapter checks, not a
full-manifest result.

Raw checks: `/Users/alex/.cache/vox/wpt/20261108-upstream-adapter-4c03f4713-raw.tar.gz`,
SHA-256 `5319db7ee605883514a0c30663d6f88833c97351537477735dbb8fb9405e9e68`.
Summary: `/Users/alex/.cache/vox/wpt/20261108-upstream-adapter-summary.json`,
SHA-256 `1c7849b0cd26fb41c733660735182b6ae3582de633c302d35ee55a7c815db49e`.
Completed Build output and locks have been removed.

The first unfiltered official-manifest collection is **running**, with all
40,139 selected variants, a 4 GiB browser cap and a 12 GiB outer guard. It starts
after the imported r18 prerequisite job ends, keeping broad suites serial.
r18 itself is deferred because its SVG production gates fail; this does not
prevent collecting an honest official-manifest baseline on the latest completed
image. The full collection pins executable
`e66ce03390efb5ef5b85d4e9009db6df414ed241d9b9b9217222e5825a767e33`
under the canonical bundle's shared read lease. Status/completion:
`/Users/alex/.cache/vox/wpt/20261108-official-testharness-{status,completion}.json`.
Supervisor: `/Users/alex/.cache/vox/wpt/20261108-official-testharness-supervisor.py`,
SHA-256 `e3617843d865b1ff67b61006304912da1f779abbdd161dba6606c33c6bd2c47c`.

To reproduce an unfiltered collection with a new output directory:

```sh
python3 tools/run_memory_bounded.py \
  --lock Build/wpt-official-UNIQUE.lock \
  --report Build/wpt-official-UNIQUE/guard.json -- \
  python3 tools/wpt_upstream_compare.py \
    --wpt-root /Users/alex/code/3rd/web-platform-tests \
    --manifest /Users/alex/.cache/vox/wpt/upstream-57bbaa12-MANIFEST.json \
    --output Build/wpt-official-UNIQUE/run
```
