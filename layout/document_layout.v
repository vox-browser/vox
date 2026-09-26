module layout

import dom

// Compatibility entry point returning the native shell's BlockBox transport.
// Geometry is produced exclusively by the typed Layout tree and LayoutState.

// Lay out `document` within a viewport `viewport_width` px wide and the document's current viewport
// height. Returns the root element's box, or an empty box when the document has no root element.
pub fn layout_document(document &dom.Document, viewport_width f64) BlockBox {
	return layout_document_in_viewport(document, viewport_width, document.viewport_rect().height)
}

// Lay out a document in an explicit viewport. CSS viewport units resolve through the Document, so
// its viewport and layout's initial containing block must describe the same rectangle.
pub fn layout_document_in_viewport(document &dom.Document, viewport_width f64, viewport_height f64) BlockBox {
	return layout_document_typed_in_viewport(document, viewport_width, viewport_height)
}
