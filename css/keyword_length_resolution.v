module css

import dom
import os

const retain_keyword_length_resolution = os.getenv('VOX_RETAIN_KEYWORD_LENGTH_RESOLUTION') != ''
const keyword_length_resolution_diagnostics = os.getenv('VOX_KEYWORD_LENGTH_RESOLUTION_DIAGNOSTICS') != ''

__global keyword_length_resolution_reported_document dom.UniqueNodeID

fn (c &ComputedProperties) report_keyword_length_rejection() {
	if !keyword_length_resolution_diagnostics { return }
	element := c.subject_element_ or { return }
	document := element.document()
	identity := document.as_node().unique_id()
	if keyword_length_resolution_reported_document != identity {
		keyword_length_resolution_reported_document = identity
		eprintln('Vox keyword length: rejected retained keyword before wrapper conversion; document=${document.url.serialize()}')
	}
}
