module layout

import dom
import os

const retain_inline_measurement_block_space = os.getenv('VOX_RETAIN_INLINE_MEASUREMENT_BLOCK_SPACE') != ''
const inline_measurement_block_space_diagnostics = os.getenv('VOX_INLINE_MEASUREMENT_BLOCK_SPACE_DIAGNOSTICS') != ''

__global inline_measurement_block_space_reported_document dom.UniqueNodeID

// Eligibility excludes floats, atomic descendants, vertical writing and line
// clamps. Those are the inline algorithm's consumers of available block space.
// Keep definite used heights and every width/constraint/input guard unchanged.
fn report_inline_measurement_block_space(root &Node) {
	if !inline_measurement_block_space_diagnostics { return }
	document := root.document()
	identity := document.as_node().unique_id()
	if inline_measurement_block_space_reported_document != identity {
		inline_measurement_block_space_reported_document = identity
		eprintln('Vox inline measurement: reused text across available block sizes; document=${document.url.serialize()}')
	}
}
