# Site optimizations

This virtual `module main` is registered in `v.mod`. `script_policy.v` owns
site-based automatic script selection; explicit launch overrides still win.
ChatGPT and GitHub retain JavaScript. Only Wikipedia defaults to static rendering.

`resources.js` is the site resource catalog consumed by the uBlock adapter.
`chatgpt.js`, `chatgpt_builder.mjs`, and `chatgpt_basic_resources.js` contain the
existing ChatGPT replacements. `github_builder.mjs` generates replacements for
two reviewed GitHub chunks, suppressing six telemetry collectors while
preserving all other factories and ES module dependencies. The core setup
factory retains its fetch nonce and defensive DOM setup. Selector-observer keeps
its registration, lifecycle and callbacks without route-metadata collection.
Unknown versioned URLs fall back to the original site code. Navigation, code-view hydration,
repository actions, Codespaces and accessibility/theme initialization remain in
the original factories.

Regenerate and verify the bundled policies from the canonical checkout:

```sh
npm --prefix tools/adblock run build
npm --prefix tools/adblock test
VOX_CHROME_TEST_FILE=site_optimizations/script_policy_test.v \
  sh tools/test_address_bar.sh -memory-limit 10G -b c -cc clang \
  -o /tmp/vox-site-script-policy-test
/tmp/vox-site-script-policy-test
```

Run expensive checks through `tools/run_memory_bounded.py` as required by
`AGENTS.md`. Reviewed compressed originals stay in `tools/adblock/fixtures/`,
where the repository permits source fixtures. Generated browser assets remain
in `adblock/`; they are rebuilt from this directory rather than hand edited.

`image_layout.v` lets GitHub image completions share the current frame's layout
boundary. `svg_path_cache.v` scopes the native small-path raster cache to GitHub
painting and restores the previous scope after nested draws. The graphics service
compares complete path geometry, transforms, colors, opacity and backdrop bytes;
it retains at most 64 entries and 8 MiB of vector storage. Unsupported paths use
the existing renderer. Graphics-memory cleanup releases the cache.

The reversible controls are `VOX_DISABLE_GITHUB_IMAGE_LAYOUT_BATCHING=1` and
`VOX_DISABLE_GITHUB_SVG_PATH_CACHE=1`. Separate diagnostics use
`VOX_GITHUB_IMAGE_LAYOUT_DIAGNOSTICS=1` and
`VOX_GITHUB_SVG_PATH_CACHE_DIAGNOSTICS=1`. The cache's sanitizer test is
`tools/native_svg_path_cache_test.cpp`; run it through the memory guard.

The combined GitHub policies pass the 20% target on the frozen full-JavaScript
launch/capture workload: 29.23% fewer observed instructions between medians,
22.19% conservatively, across seven matched pairs with exact original
pixels. See [the measured scope and evidence](../docs/GITHUB_SITE_OPTIMIZATIONS.md);
this does not establish live-site performance or isolated rendering cost.

`github_css_builder.mjs` and `github_css.js` reuse four already-loaded component
entry sheets when the original Rspack loader asks for byte-equivalent chunk CSS.
`initial_stylesheets.v` removes repeated reviewed Primer sheets before bootstrap,
retaining the last owner and the original layer order. `stylesheet_layout.v`
keeps CSSOM's targeted invalidation in charge after an asynchronous sheet
completes. It preserves broad invalidation for layer changes and other rules
that require it, without forcing unrelated elements through another style pass.

`animation_wakeups.v` avoids redundant animation-only display grants after
finite CSS effects complete and for scroll timelines driven by input.
`animation_clock_demand.v` declines redundant style invalidations when those
effects have no new sample. Active effects retain normal grants in every
visibility state. The engine still processes animation events and timeline
updates; JavaScript time reads use the document clock between display callbacks.
Seeks and changed scroll sources request another style sample. Relevant Web
Animations and CSS transitions retain the conservative path.

Additional controls are `VOX_DISABLE_GITHUB_INITIAL_STYLESHEET_DEDUP=1`,
`VOX_DISABLE_GITHUB_STYLESHEET_LAYOUT_REUSE=1` and
`VOX_DISABLE_GITHUB_ANIMATION_WAKEUP_THROTTLING=1`. Diagnostic switches are
listed in the corresponding V files. Production diagnostics have exercised the
idle-clock policy; they do not establish the requested instruction reduction.

`raster_inputs.v` compares supported static paint values across display-list
generations before using the existing stationary viewport raster. Its key
includes path coordinates, bitmap pixels and formats, response bytes and image
decode availability. It applies the renderer's existing scope-aware culler and
uniform viewport-fill rule. Visible empty or deferred bitmaps, unknown commands,
live media and complex SVG resources keep the existing revision key; filter and
mask inputs remain relevant outside the viewport. Native owner, viewport,
transform and independent content guards still apply. Disable this policy with
`VOX_DISABLE_GITHUB_RASTER_INPUT_REUSE=1`; inspect eligibility with
`VOX_GITHUB_RASTER_INPUT_DIAGNOSTICS=1`. Focused cases pass with reuse enabled
and disabled. Production diagnostics verify eligibility; the matched combined-policy
comparison and its limits are recorded in the report above.

`cosmetic_tokens.v` keeps GitHub's ID/class token survey across text-only,
unrelated-attribute, detached and shadow-tree changes. Generic DOM counters
track connected light-DOM element membership and ID/class edits; every relevant
input still invalidates the survey. Procedural filtering and live CSS matching
continue normally. Disable it with `VOX_DISABLE_GITHUB_COSMETIC_TOKEN_REUSE=1`;
`VOX_GITHUB_COSMETIC_TOKEN_DIAGNOSTICS=1` reports the precise reuse path.
