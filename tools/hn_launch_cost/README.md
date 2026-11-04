# Hacker News launch cost diagnostics

These tools preserve the launch pilot and sampling probes from
`Build/hn-1800c-20261104/{driver.py,probe/}`. Generated libraries, samples, profiles,
PNGs and counters belong in a unique `Build/` directory. Use the canonical
`Build/v/Vox.app` without copying bundles or repository tools.

The pilot calls `hacker_news_browser_instructions.run_browser`: fresh process,
private profile/cache, sealed home-page replay, exclusive resource-coalition
instructions from creation through encoded PNG, unchanged pixel reference and
all 30 story IDs. Native libraries, helper/resources, runtime assets, tools,
fixture and reference hashes are checked before and after each attempt. Every
attempt is retained. An invalid or incomplete variant gets no median or paired
savings. Variant order rotates each round. Read host load in `rows.json` and the
memory guard receipt when assessing variation.

A six-trial Vox-only baseline (choose a new output name):

```sh
env -u ALL_PROXY -u HTTP_PROXY -u HTTPS_PROXY -u NO_PROXY \
    -u all_proxy -u http_proxy -u https_proxy -u no_proxy \
  python3 tools/run_memory_bounded.py \
    --lock Build/hn-pilot-UNIQUE.lock --report Build/hn-pilot-UNIQUE-guard.json \
    --adopt-pids-from Build/hn-pilot-UNIQUE-pids.json -- \
  python3 tools/hacker_news_launch_pilot.py Build/hn-pilot-UNIQUE 6 \
    base=Build/v/Vox.app --memory-guard-registry Build/hn-pilot-UNIQUE-pids.json
```

`--diff-tool` selects an existing verified pixel-diff binary (default:
`Build/pixel-tools/pixel_diff`). Check the latest production receipt and run
`tools/prune_stale_launchservices.py --identifier org.ladybirdbrowser.vox --json`
before measuring. The pilot rejects a shared build changing during a run; retain
that attempt and start a complete new pilot. It never schedules a build.

For a same-binary diagnostic, add variants such as
`control=Build/v/Vox.app candidate=Build/v/Vox.app:VOX_EXAMPLE=1`.
Environment variants and injected libraries are diagnostic, not production
acceptance. Vox-only pilots cannot establish Brave acceptance; use the canonical
seven-pair command in `AGENTS.md`, retaining failed cohorts and rerunning whole
cohorts if an ownership audit fails. Do not change references or tolerances.

Build the sampling delay in a generated-output directory, through the guard:

```sh
mkdir -p Build/hn-probes-UNIQUE
python3 tools/run_memory_bounded.py --limit-gib 3 \
  --lock Build/hn-probes-UNIQUE/compile.lock \
  --report Build/hn-probes-UNIQUE/compile.json -- \
  clang -dynamiclib -O2 -Wall -Wextra -Werror tools/hn_launch_cost/delay.c \
    -o Build/hn-probes-UNIQUE/delay.dylib
```

Run `tools/hn_launch_cost/sampler.py OUTPUT RUNS --delay-library DYLIB
--memory-guard-registry PATH` through the guard with the same adoption registry
and proxy variables removed, as for the pilot. It attaches `/usr/bin/sample` to
Vox and its adblock worker. It deliberately delays load/exit to retain symbols;
counts from these runs cannot establish performance gains. It records both
sampler exits, thread/busy counts, and rejects missing or empty call graphs.
Nonempty samples can still miss startup; inspect the function coverage before
attributing costs. `--app`, `--seconds` and `--diff-tool`
are optional.

Analyze the resulting samples without browser launches:

```sh
python3 tools/hn_launch_cost/aggregate.py 'Build/RUN/trial-*-sampled/sample-vox.txt' --thread main --top 30
python3 tools/hn_launch_cost/aggregate.py 'Build/RUN/trial-*-sampled/sample-worker.txt' --self
python3 tools/hn_launch_cost/tree.py 'Build/RUN/trial-*-sampled/sample-vox.txt' FUNCTION 5 .3
```

`aggregate.callers(files, needle, depth=4, top=25)` prints reverse caller paths.
Aggregations exclude waiting leaves and delay functions and count recursion
once per stack. These are sampled stacks, not retired-instruction attribution.

`bitmaps.c` and `frames.c` are optional CoreGraphics interposers. Compile either
with `clang -dynamiclib -O2 -framework CoreGraphics` through the guard, and pass
its library as `DYLD_INSERT_LIBRARIES` in a diagnostic pilot variant. Bitmap
creation sizes go to stderr; the frame probe hashes large bitmap images and
counts nonwhite rows. Hashing scans and faults in frame memory: its instruction
counts must never supply optimization credit. See `hn-launch-cost-map.md` in the
original memory directory and `docs/benchmark-results/hacker-news-1800-reached-2026-11-04.json`
for the earlier cost map and accepted 1.8B result.

`glyphs.c` interposes the Skia glyph and colored SVG path entry points and reports
aggregate call, glyph and browser-process instruction counts at exit. Compile with the same
CoreGraphics command plus `-undefined dynamic_lookup`. Its weak import allows
the adblock worker to inherit the probe without linking Skia. Process-counter
reads include their own overhead and concurrent browser threads; use only to
locate work, with unchanged pixels/content, never as an acceptance result.

`coregraphics.c` similarly counts clipping, image, rectangle and path API calls.
Compile with the CoreGraphics command. Nested API totals overlap, and totals
include startup/chrome calls as well as document rendering. Do not add them to
each other or to the glyph probe's total.
