module layout

import css
import dom

// A minimal block formatting context: it consumes the css computed-value layer (computed lengths,
// percentages) to produce real box geometry, including the box model — margins, padding, and
// borders. Block boxes stack vertically; each is sized within its containing block's content width;
// a box with `height: auto` takes the height of its stacked children. This is the first layout code
// that actually runs on the cascade output — and where percentage widths (which computed_length_px
// can't resolve without a containing block) get resolved.
//
// FIXME (deliberately out of scope for this slice): inline/text layout, `display` handling (every
// element child is treated as a block), floats, vertical margin collapsing, `auto` margin resolution
// (centering / distributing remaining space — `auto` margins are treated as 0 here), and definite
// percentage heights.

// The used thickness of a box's four edges (margin / padding / border), in CSS px.
pub struct BoxEdges {
pub:
	top    f64
	right  f64
	bottom f64
	left   f64
}

// A laid-out block box: `x`/`y`/`width`/`height` are the *content box* geometry in CSS px, relative
// to the top-left of the initial containing block; `margin`/`border`/`padding` surround it.
pub struct BlockBox {
pub:
	tag_name string
pub mut:
	x        f64
	y        f64
	width    f64
	height   f64
	margin   BoxEdges
	border   BoxEdges
	padding  BoxEdges
	children []BlockBox
}

// The margin-box height: the vertical space this box occupies in its parent's flow.
pub fn (b &BlockBox) margin_box_height() f64 {
	return b.margin.top + b.border.top + b.padding.top + b.height + b.padding.bottom +
		b.border.bottom + b.margin.bottom
}

// The margin-box width: content plus padding, border, and margin on both sides.
pub fn (b &BlockBox) margin_box_width() f64 {
	return b.margin.left + b.border.left + b.padding.left + b.width + b.padding.right +
		b.border.right + b.margin.right
}

// A length/percentage property resolved to px, or 0 when it's `auto`/absent/other. Percentages
// resolve against `basis` (for margins and padding that's the containing block's width, per spec).
fn used_length_or_zero(element &dom.Element, property_name string, basis f64, author_rules []&css.CSSRule) f64 {
	id := css.property_id_from_string(property_name) or { return 0 }
	if px := css.computed_length_px(element, id, author_rules) {
		return px
	}
	if pct := css.computed_percentage(element, id, author_rules) {
		return basis * pct / 100.0
	}
	return 0
}

// The used border width for one side. Per spec the computed border width is 0 when the corresponding
// border-style is `none`/`hidden`; otherwise it's the border-width length, or the thin/medium/thick
// keyword scale (1/3/5 px).
fn used_border(element &dom.Element, side string, author_rules []&css.CSSRule) f64 {
	style_id := css.property_id_from_string('border-${side}-style') or { return 0 }
	style := css.cascaded_value_with_ua(element, style_id, author_rules)
	if style == 'none' || style == 'hidden' {
		return 0
	}
	width_id := css.property_id_from_string('border-${side}-width') or { return 0 }
	if px := css.computed_length_px(element, width_id, author_rules) {
		return px
	}
	return match css.cascaded_value_with_ua(element, width_id, author_rules) {
		'thin' { 1.0 }
		'thick' { 5.0 }
		else { 3.0 } // 'medium' (the initial value) and any unresolved keyword
	}
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

// The used content width for `element` in a containing block `containing_width` px wide: a length or
// percentage gives the content width directly; `auto` fills the space left after the horizontal
// margins, borders, and padding (`horizontal_extra`), clamped at 0.
fn used_content_width(element &dom.Element, containing_width f64, horizontal_extra f64, author_rules []&css.CSSRule) f64 {
	width_id := css.property_id_from_string('width') or { return containing_width - horizontal_extra }
	if px := css.computed_length_px(element, width_id, author_rules) {
		return px
	}
	if pct := css.computed_percentage(element, width_id, author_rules) {
		return containing_width * pct / 100.0
	}
	remaining := containing_width - horizontal_extra
	return if remaining > 0 { remaining } else { 0 }
}

// Lay out `element` and its block descendants. `x`/`y` is the top-left of this box's *margin box*;
// the returned box's content origin is inset by its margin, border, and padding. Children stack
// vertically within the content box, each advancing the cursor by its own margin-box height; the
// parent's content height is that stacked total unless it declares an explicit height.
pub fn layout_block(element &dom.Element, x f64, y f64, containing_width f64, author_rules []&css.CSSRule) BlockBox {
	margin := BoxEdges{
		top:    used_length_or_zero(element, 'margin-top', containing_width, author_rules)
		right:  used_length_or_zero(element, 'margin-right', containing_width, author_rules)
		bottom: used_length_or_zero(element, 'margin-bottom', containing_width, author_rules)
		left:   used_length_or_zero(element, 'margin-left', containing_width, author_rules)
	}
	border := BoxEdges{
		top:    used_border(element, 'top', author_rules)
		right:  used_border(element, 'right', author_rules)
		bottom: used_border(element, 'bottom', author_rules)
		left:   used_border(element, 'left', author_rules)
	}
	padding := BoxEdges{
		top:    used_length_or_zero(element, 'padding-top', containing_width, author_rules)
		right:  used_length_or_zero(element, 'padding-right', containing_width, author_rules)
		bottom: used_length_or_zero(element, 'padding-bottom', containing_width, author_rules)
		left:   used_length_or_zero(element, 'padding-left', containing_width, author_rules)
	}
	horizontal_extra := margin.left + margin.right + border.left + border.right + padding.left +
		padding.right
	width := used_content_width(element, containing_width, horizontal_extra, author_rules)

	content_x := x + margin.left + border.left + padding.left
	content_y := y + margin.top + border.top + padding.top

	mut children := []BlockBox{}
	mut child_y := content_y
	for child in block_child_elements(element.as_node()) {
		child_box := layout_block(child, content_x, child_y, width, author_rules)
		child_y += child_box.margin_box_height()
		children << child_box
	}
	content_height := child_y - content_y

	height_id := css.property_id_from_string('height') or { return BlockBox{} }
	height := if px := css.computed_length_px(element, height_id, author_rules) {
		px
	} else {
		content_height
	}

	return BlockBox{
		tag_name: element.local_name()
		x:        content_x
		y:        content_y
		width:    width
		height:   height
		margin:   margin
		border:   border
		padding:  padding
		children: children
	}
}
