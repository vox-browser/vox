module main

import dom
import layout

// Raster tiling follows the root scrolling surface. Shadow and filter ink can
// extend beyond it without increasing the document's scrollable dimensions.
fn chromium_root_raster_extent(document &dom.Document) ?layout.LayoutRect {
	if document == unsafe { nil } { return none }
	result := layout.document_layout_result(document) or { return none }
	return result.paint_tree.scrollable_overflow
}
