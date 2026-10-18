# Native search form submission

2026-10-18, implementation `5e19ae0f`. One completed fix for the non-optimization
ten-fix verification cadence; this slice runs focused checks only.

Enter and submit-input activation previously stopped at an optional input action
hook that the browser never installed. Form submission likewise stopped after
constructing its typed submission record. A button additionally required a form
model to have been created beforehand.

Inputs and buttons now obtain their owning form model and run its existing
submission algorithm. Forms discover lazy controls in their light-tree root,
including controls associated by `form` ID, before validating and constructing
the ordered entry list. Default-button and implicit-submission blocker discovery
use that same membership. GET submissions without a host override use the owning
navigable's existing native URL handoff for the current browsing context.

The upstream algorithm references are `HTML/HTMLInputElement.cpp`,
`HTML/HTMLButtonElement.cpp`, and `HTML/HTMLFormElement.cpp` in
`~/code/3rd/ladybird/Libraries/LibWeb`. Lazy control discovery and the default
native URL handoff are V browser integration boundaries. POST bodies and auxiliary
targets still require the typed submission hook; this fix does not claim full
form-navigation or compact JavaScript event parity.

Verification:

- Seven cases in `main_form_submission_test.v` pass with default GC and with
  `-gc none`. They exercise the shell's Enter and pointer callbacks, live Unicode
  query encoding, untouched controls, button descendants and action overrides,
  submit cancellation, disabled defaults, multiple blocking fields, `formdata`
  mutation, and required-field validation. Assertions check queued navigation
  destinations without making requests to Reddit.
- `main_keyboard_input_test.v` passes with `-gc none`.
- Existing activation, form-element, entry-construction, submit-event,
  duplicate-ID ownership, and reset-dispatch test files pass. The first two
  successful file results are retained from an interrupted selection; the other
  four have a completed selection with exit zero. Failed disk-space attempts and
  interrupted builds receive no pass credit.
- A fresh optimized Boehm bundle built successfully using the standard build
  script with only its output directory redirected to
  `Build/form-search/production/`. Signing verification and `--headless-smoke`
  both pass. The standard `Build/v/Vox.app`, produced by a concurrent build,
  also passes signing and startup. Its compiled input/button submission calls,
  implicit-submission call, lazy-control discovery symbol, and form-to-navigable
  call were verified directly. That already updated canonical bundle is
  preserved rather than overwritten by the isolated output.

Local logs and owned-source identities are under ignored `Build/form-search/`.
The synthetic fixtures contain no saved authenticated page content.
