module layout

import css
import dom

// The top-level reflow entry point: HTML+CSS document -> box tree. It collects the document's author
// style rules, finds the root element, and lays it out within a viewport `viewport_width` px wide.
// This mirrors a browser's reflow at a coarse level: the viewport is the initial containing block,
// the root element fills it (width:auto), and height flows from content.
//
// FIXME: percentage heights and the root filling the viewport when its content is shorter aren't
// modeled; the UA/author cascade here is the minimal one, not the full StyleComputer.

// Collect author style rules from the document's <style> elements, in document order, parsing each
// element's text content as a stylesheet.
//
// FIXME: external sheets (<link rel=stylesheet>) and @import aren't fetched, and <style media=...>
// isn't filtered.
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
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_viewport_rect(dom.Rect{0, 0, viewport_width, viewport_height})

	// Flatten @media rules against the viewport width so the matching ones participate in the cascade.
	author_rules := css.flatten_media_rules(collect_document_author_rules(document), viewport_width)
	root_element := document.document_element() or { return BlockBox{} }
	mut root_box := layout_block(root_element, 0, 0, viewport_width, author_rules)

	// C++ LibWeb paints the root background across the canvas. If <html> is transparent, the HTML
	// body's background is propagated to that canvas and omitted from the body's own box.
	mut canvas_background := root_box.background_color
	if canvas_background.a == 0 {
		for i, child in root_box.children {
			if child.tag_name == 'body' && child.background_color.a > 0 {
				canvas_background = child.background_color
				root_box.children[i].background_color = css.Color{0, 0, 0, 0}
				break
			}
		}
	}
	if canvas_background.a > 0 {
		root_box.canvas_background_color = canvas_background
		root_box.canvas_width = viewport_width
		root_box.canvas_height = viewport_height
		root_box.background_color = css.Color{0, 0, 0, 0}
	}

	// Absolutely positioned elements with no positioned ancestor resolve against the initial
	// containing block (the viewport).
	icb := PositionedContainingBlock{
		x:      0
		y:      0
		width:  viewport_width
		height: viewport_height
	}
	for abspos in collect_abspos_in_scope(unsafe { &dom.Node(document) }, author_rules) {
		root_box.children << layout_absolute(abspos, icb, author_rules)
	}
	return root_box
}
