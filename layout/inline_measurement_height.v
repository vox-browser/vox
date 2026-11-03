module layout

import dom
import os

const retain_inline_measurement_indefinite_height = os.getenv('VOX_RETAIN_INLINE_MEASUREMENT_INDEFINITE_HEIGHT') != ''
const inline_measurement_height_diagnostics = os.getenv('VOX_INLINE_MEASUREMENT_HEIGHT_DIAGNOSTICS') != ''

__global indefinite_inline_measurement_reported_document dom.UniqueNodeID

// Closed text-only inline measurement has no percentage-height descendants or
// atomic boxes. An indefinite stored height supplies no basis to the line
// builder. Keep availability, constraints and definiteness in the key, while
// allowing a later probe to carry a different unused numeric height.
fn report_indefinite_inline_measurement_height(root &Node) {
	if !inline_measurement_height_diagnostics { return }
	document := root.document()
	identity := document.as_node().unique_id()
	if indefinite_inline_measurement_reported_document != identity {
		indefinite_inline_measurement_reported_document = identity
		eprintln('Vox inline measurement: reused text across indefinite stored heights; document=${document.url.serialize()}')
	}
}
