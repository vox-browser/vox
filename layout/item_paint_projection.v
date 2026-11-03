module layout

import dom
import os

const retain_uncached_item_paint = os.getenv('VOX_RETAIN_UNCACHED_ITEM_PAINT') != ''
const item_paint_projection_diagnostics = os.getenv('VOX_ITEM_PAINT_PROJECTION_DIAGNOSTICS') != ''

__global item_paint_projection_reported_document dom.UniqueNodeID

fn report_item_paint_projection(node &Node) {
	if !item_paint_projection_diagnostics { return }
	document := node.document()
	identity := document.as_node().unique_id()
	if item_paint_projection_reported_document != identity {
		item_paint_projection_reported_document = identity
		eprintln('Vox item paint: reused unchanged flex or grid item projection; document=${document.url.serialize()}')
	}
}
