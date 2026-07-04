module layout

import css
import dom

// A minimal block formatting context: it consumes the css computed-value layer (computed lengths,
// percentages) to produce real box geometry. Block boxes stack vertically, each sized within its
// containing block's width; a box with `height: auto` takes the height of its stacked children.
// This is the first layout code that actually runs on the cascade output — and where percentage
// widths (which computed_length_px can't resolve without a containing block) get resolved.
//
// FIXME (deliberately out of scope for this slice): margins/padding/borders, inline/text layout,
// `display` handling (every element child is treated as a block), floats, and definite percentage
// heights.

// A laid-out block box: content-box geometry in CSS px, relative to the top-left of the initial
// containing block.
pub struct BlockBox {
pub:
	tag_name string
pub mut:
	x        f64
	y        f64
	width    f64
	height   f64
	children []BlockBox
}

// Used content width for `element` within a containing block `containing_width` px wide: a length
// resolves to px; a percentage resolves against the containing width; `auto` (and anything else)
// fills the containing block — block-level `width: auto` uses the available width.
fn used_block_width(element &dom.Element, containing_width f64, author_rules []&css.CSSRule) f64 {
	width_id := css.property_id_from_string('width') or { return containing_width }
	if px := css.computed_length_px(element, width_id, author_rules) {
		return px
	}
	if pct := css.computed_percentage(element, width_id, author_rules) {
		return containing_width * pct / 100.0
	}
	return containing_width
}

// Used content height for `element`: a length resolves to px; `auto` (and percentages, which need a
// definite containing-block height this engine doesn't track) fall back to `content_height` — the
// total height of the laid-out children.
fn used_block_height(element &dom.Element, content_height f64, author_rules []&css.CSSRule) f64 {
	height_id := css.property_id_from_string('height') or { return content_height }
	if px := css.computed_length_px(element, height_id, author_rules) {
		return px
	}
	return content_height
}

// The element children of `node`, in document order (text and other node types are skipped — this
// engine models block boxes only).
fn block_child_elements(node &dom.Node) []&dom.Element {
	mut elements := []&dom.Element{}
	for child in node.children_as_vector() {
		if element := child.as_element() {
			elements << element
		}
	}
	return elements
}

// Lay out `element` and its block descendants: block boxes stack vertically starting at content-box
// origin (`x`, `y`), each filling (or sized within) the containing block's width; the parent's
// content height is the sum of its children's heights, unless it declares an explicit height.
pub fn layout_block(element &dom.Element, x f64, y f64, containing_width f64, author_rules []&css.CSSRule) BlockBox {
	width := used_block_width(element, containing_width, author_rules)
	mut children := []BlockBox{}
	mut child_y := y
	for child in block_child_elements(element.as_node()) {
		child_box := layout_block(child, x, child_y, width, author_rules)
		child_y += child_box.height
		children << child_box
	}
	content_height := child_y - y
	height := used_block_height(element, content_height, author_rules)
	return BlockBox{
		tag_name: element.local_name()
		x:        x
		y:        y
		width:    width
		height:   height
		children: children
	}
}
