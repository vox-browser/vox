module css

import dom
import os

const retain_absolute_length_context = os.getenv('VOX_RETAIN_ABSOLUTE_LENGTH_CONTEXT') != ''
const exact_layout_length_diagnostics = os.getenv('VOX_EXACT_LAYOUT_LENGTH_DIAGNOSTICS') != ''

__global exact_layout_length_reported_document dom.UniqueNodeID

// Both layout rounding policies agree on zero CSS pixels. The direct guard
// leaves all nonzero values and other units on their ordinary resolution path.
fn (c &ComputedProperties) report_exact_layout_length() {
	if !exact_layout_length_diagnostics { return }
	if subject := c.subject_element_ {
		document := subject.document()
		identity := document.as_node().unique_id()
		if exact_layout_length_reported_document != identity {
			exact_layout_length_reported_document = identity
			eprintln('Vox absolute length: exact fixed-point value skipped rounding context; document=${document.url.serialize()}')
		}
	}
}
