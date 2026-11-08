module css

import os

// Raw rules only read their prelude before conversion. Borrow the contiguous
// component input, as declaration values already do; retained CSSOM conversion
// still owns any components that escape a transient parsing workspace.
const disable_borrowed_rule_preludes = os.getenv('VOX_DISABLE_BORROWED_RULE_PRELUDES') != ''
const disable_borrowed_selector_spans = os.getenv('VOX_DISABLE_BORROWED_SELECTOR_SPANS') != ''
const disable_flat_component_source = os.getenv('VOX_DISABLE_FLAT_COMPONENT_SOURCE') != ''
const borrowed_selector_span_diagnostics = os.getenv('VOX_BORROWED_SELECTOR_SPANS_DIAGNOSTICS') != ''
const flat_component_source_diagnostics = os.getenv('VOX_FLAT_COMPONENT_SOURCE_DIAGNOSTICS') != ''
__global borrowed_selector_span_reported bool
__global flat_component_source_reported bool
