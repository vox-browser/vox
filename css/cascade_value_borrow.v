module css

import dom
import os

const retain_cascade_value_copies = os.getenv('VOX_RETAIN_CASCADE_VALUE_COPIES') != ''
const cascade_value_borrow_diagnostics = os.getenv('VOX_CASCADE_VALUE_BORROW_DIAGNOSTICS') != ''

__global cascade_value_borrow_reported_document dom.UniqueNodeID

fn report_cascade_value_borrow(element dom.AbstractElement) {
	if !cascade_value_borrow_diagnostics { return }
	document := element.element().document()
	identity := document.as_node().unique_id()
	if cascade_value_borrow_reported_document != identity {
		cascade_value_borrow_reported_document = identity
		eprintln('Vox cascade value: read retained tag without copying wrapper; document=${document.url.serialize()}')
	}
}
