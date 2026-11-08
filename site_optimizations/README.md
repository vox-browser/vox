# Site optimizations

This virtual `module main` is registered in `v.mod`. `script_policy.v` owns
site-based automatic script selection; explicit launch overrides still win.
ChatGPT and GitHub retain JavaScript. Only Wikipedia defaults to static rendering.

`resources.js` is the site resource catalog consumed by the uBlock adapter.
`chatgpt.js`, `chatgpt_builder.mjs`, and `chatgpt_basic_resources.js` contain the
existing ChatGPT replacements. `github_builder.mjs` generates replacements for
two reviewed GitHub chunks, suppressing four analytics/metrics factories while
preserving all other factories and ES module dependencies. Unknown versioned
URLs fall back to the original site code. Navigation, code-view hydration,
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

Removing collection code does not establish a rendering instruction reduction.
The GitHub 20% target remains open; see
[the diagnostic report](../docs/GITHUB_SITE_OPTIMIZATIONS.md) before making a
performance claim.
