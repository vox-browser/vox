# Full upstream WPT inventory and execution status

The full upstream checkout has been fetched. **The official runner stopped
before executing any tests. There is no full-suite Vox pass rate.** The earlier
3,808-case runs cover Ladybird's imported expectation cohort only.

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

## Execution attempts

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
