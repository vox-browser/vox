# Wikipedia rendering against Brave

Vox renders https://www.wikipedia.org/ as HTML and CSS only (`wikipedia.org`
is in `html_css_only_sites` in `main_script_policy.v`). The comparison target
is Brave with page JavaScript disabled.

**Exact equality has not been reached.** From the frozen benchmark cache, at a
1024×768 viewport and device scale 1, Vox differs from Brave at 12 of 786,432
pixels (0.0015%). The difference is the same in every run.

Vox retires 5.85–5.92 billion instructions from launch to the finished
capture; Brave retires 8.02–8.13 billion. The worst Vox run is 26% below the
best Brave run (five Vox runs and three Brave runs on 2026-10-17). The
benchmark gives credit only to pixel-exact samples, so it does not pass until
the last 12 pixels match.

## Method

- **Browsers:** Brave 155.1.97.57 (Chromium 155) and Vox on macOS. Both load
  the same frozen copy of the page and its images; missing responses fail
  offline.
- **Reference:** Brave runs headless with author JavaScript disabled through
  CDP before navigation:

  ```sh
  python3 tools/wikipedia_browser_instructions.py --cache Build/wikipedia-instructions-cache \
    --output Build/wikipedia-ref --capture-reference
  ```

- **Benchmark:** alternating Vox and Brave samples, counting retired
  instructions (`proc_pid_rusage`) for each browser's process tree. Every
  sample must match the reference exactly; the run passes when the worst Vox
  sample is at least 20% below the best Brave sample:

  ```sh
  python3 tools/wikipedia_browser_instructions.py --cache Build/wikipedia-instructions-cache \
    --output Build/wikipedia-bench --expected Build/wikipedia-ref/brave-reference.png
  ```

- **Comparison:** every channel difference counts. No tolerance or masked
  region is used.

## Rendering changes

All native browser documents use the Chromium compatibility policy
(`font_rendering_policy`), including local files and saved pages regardless of
their base URL.

- **Focus:** Chromium matches `:focus` and paints the caret only in a focused,
  active window. A screenshot run captures like headless Chromium, so the
  autofocused search box is drawn unfocused.
- **Multi-column layout:** the no-script language lists use `column-width`.
  A multi-column container whose content is inline is laid out at the column
  width and balanced into columns: greedy fill with orphans and widows of 2,
  grown by the smallest space shortage, as LayoutNG does.
- **Whitespace:**
  - A line is aligned without its trailing collapsible spaces.
  - Spaces in non-wrapping text collapse across element boundaries.
  - A dropped space keeps the end padding of the inline boxes it closes.
  - After trimming a trailing space, the text item is snapped up again from
    its unsnapped advance.
- **Fonts:**
  - Devanagari uses Kohinoor Devanagari, as Brave falls through to
    `sans-serif` instead of the system font's `.SF Devanagari`.
  - Characters that fall back to the same face share one font, so they are
    shaped as one run.
  - Installed faces take their bounds from CoreText.
- **Geometry and painting:**
  - Relative offsets are truncated toward zero, as `LayoutUnit(float)` does.
  - An inline box paints its background, borders and shadow across its nested
    inline boxes.

## Performance changes

- The document heap is sized from the markup before the first parse, which
  avoids about ten collections while the heap grows.
- The autofocus flush runs before the first layout, so the input's shadow tree
  is built once instead of forcing a second layout and paint.
- The document walk that sizes the heap compares nodes by identity, avoiding
  heap copies in `Node`'s `==` operator.

Capture frames at the screenshot scale, reuse of the presented frame for the
capture, and readiness polling without repainting were landed separately on
master.

## Remaining differences

- **Search box corners (7 pixels):** the input's border has no right side and
  rounded left corners. Blink clips to the outer rounded rectangle, clips out
  the inner one, and fills the sides, with analytic edge coverage. Vox fills a
  polygonal border path.
- **Wordmark (5 pixels):** a few edge pixels of the "Wikipedia" wordmark,
  which is drawn from the SVG sprite, differ in GPU coverage.
- **Live content:** article counts change. Compare a reference and a capture
  taken from the same page version.

## Validation

Each change has focused tests that pass in the default and `-gc none` builds.
Each also passed:

- every `Tests/Browser/Brave` fixture and the old-Reddit exact gate;
- the eleven default screenshot smoke cases;
- the native capture fixture tests.
