# V layout expectation overrides

The corpus runner normally compares against Ladybird's checked-in layout dumps.
Files below this directory replace individual upstream dumps when the current
upstream implementation has intentionally changed but its older static fixture
has not been regenerated yet.

- `css-values/trigonometric-functions.txt` reflects calculated
  length-percentage truncation from Ladybird commit `2adcf1f738f`.
- `flex/flex-item-with-percentage-width-in-flex-container-with-definite-max-width.txt`
  reflects the current Rust flex and line-layout implementation; the upstream
  expected file still records the pre-Rust-layout font geometry.

Remove an override when upstream refreshes the corresponding expected dump.
