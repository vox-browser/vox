module layout

import css
import dom

// Compatibility entry point returning the native shell's BlockBox transport.
// Geometry is produced exclusively by the typed Layout tree and LayoutState.

// Collect author style rules from the document's <style> elements, in document order, parsing each
// element's text content as a stylesheet.
//
pub fn collect_document_author_rules(document &dom.Document) []&css.CSSRule {
	root := unsafe { &dom.Node(document) }
	mut rules := []&css.CSSRule{}
	for style_element in css.query_selector_all(root, 'style') {
		text := style_element.as_node().text_content() or { continue }
		rules << css.parse_css_stylesheet_contents_with_parser(text, map[string]bool{})
	}
	return rules
}

// Lay out `document` from its root element within a viewport `viewport_width` px wide, applying the
// author rules from its <style> elements on top of the UA sheet. Returns the root element's box, or
// an empty box when the document has no root element.
pub fn layout_document(document &dom.Document, viewport_width f64) BlockBox {
	return layout_document_in_viewport(document, viewport_width, document.viewport_rect().height)
}

// Lay out a document in an explicit viewport. CSS viewport units resolve through the Document, so
// its viewport and layout's initial containing block must describe the same rectangle.
pub fn layout_document_in_viewport(document &dom.Document, viewport_width f64, viewport_height f64) BlockBox {
	return layout_document_typed_in_viewport(document, viewport_width, viewport_height)
}
