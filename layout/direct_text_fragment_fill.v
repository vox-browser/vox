module layout

import dom
import os

const retain_copied_text_fragment_append = os.getenv('VOX_RETAIN_COPIED_TEXT_FRAGMENT_APPEND') != ''
const direct_text_fragment_fill_diagnostics = os.getenv('VOX_DIRECT_TEXT_FRAGMENT_FILL_DIAGNOSTICS') != ''

__global direct_text_fragment_fill_reported_document dom.UniqueNodeID

fn report_direct_text_fragment_fill(root &Node) {
	if !direct_text_fragment_fill_diagnostics { return }
	document := root.document()
	identity := document.as_node().unique_id()
	if direct_text_fragment_fill_reported_document != identity {
		direct_text_fragment_fill_reported_document = identity
		eprintln('Vox text paint transport: filled final fragment slots; document=${document.url.serialize()}')
	}
}
