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
// Adjoining vertical margins of in-flow siblings collapse (CSS 2.1 §8.3.1).
//
// FIXME (deliberately out of scope for this slice): inline/text layout, `display` handling (every
// element child is treated as a block), floats, parent/child and self (empty-block) margin
// collapsing, `auto` margin resolution (centering / distributing remaining space — `auto` margins
// are treated as 0 here), and definite percentage heights.

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

// The used margins of `element` (each `auto`/absent margin is 0 — no centering yet). Percentages
// resolve against the containing block's width. Factored out so the parent can peek a child's top
// margin before laying it out, to position it with margin collapsing.
fn used_margins(element &dom.Element, containing_width f64, author_rules []&css.CSSRule) BoxEdges {
	return BoxEdges{
		top:    used_length_or_zero(element, 'margin-top', containing_width, author_rules)
		right:  used_length_or_zero(element, 'margin-right', containing_width, author_rules)
		bottom: used_length_or_zero(element, 'margin-bottom', containing_width, author_rules)
		left:   used_length_or_zero(element, 'margin-left', containing_width, author_rules)
	}
}

// Collapse a set of adjoining vertical margins into one, per CSS 2.1 §8.3.1: the largest positive
// margin plus the most negative margin (so max positive when all positive; their difference when
// mixed; the most negative when all negative).
fn collapse_margins(margins []f64) f64 {
	mut max_positive := 0.0
	mut min_negative := 0.0
	for m in margins {
		if m > max_positive {
			max_positive = m
		}
		if m < min_negative {
			min_negative = m
		}
	}
	return max_positive + min_negative
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

// Whether a computed `display` value generates a block-level box in this engine. `none` generates
// no box at all; inline-level values (inline / inline-block / inline-*) are skipped because there is
// no inline formatting context yet. Everything else (block, list-item, flow-root, and — as a coarse
// approximation — flex/grid/table, which are block-level in their parent's flow) is laid out as a
// block. FIXME: `display: contents` should hoist the children rather than generate a box.
fn is_block_level_display(display string) bool {
	if display == 'none' {
		return false
	}
	return !display.starts_with('inline')
}

// The block-level element children of `node`, in document order. Text and other node types are
// skipped (no inline formatting context yet), as are elements whose computed `display` is `none` or
// inline-level — so `<head>`/`<script>`/`<style>` and inline elements no longer generate boxes.
fn block_child_elements(node &dom.Node, author_rules []&css.CSSRule) []&dom.Element {
	display_id := css.property_id_from_string('display') or { return []&dom.Element{} }
	mut elements := []&dom.Element{}
	for child in node.children_as_vector() {
		if element := child.as_element() {
			display := css.cascaded_value_with_ua(element, display_id, author_rules)
			if is_block_level_display(display) {
				elements << element
			}
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
	margin := used_margins(element, containing_width, author_rules)
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

	// Lay children out in flow. Adjoining vertical margins collapse (CSS 2.1 §8.3.1): the gap
	// between a child's top border edge and the previous child's bottom border edge is the collapse
	// of the previous child's bottom margin with this child's top margin, not their sum. `flow_bottom`
	// tracks the previous child's bottom *border* edge; each child's margin box is positioned so its
	// border-box top lands at `flow_bottom + collapsed_gap`.
	mut children := []BlockBox{}
	mut flow_bottom := content_y
	mut prev_bottom_margin := 0.0
	mut has_prev := false
	for child in block_child_elements(element.as_node(), author_rules) {
		child_margins := used_margins(child, width, author_rules)
		gap := if has_prev {
			collapse_margins([prev_bottom_margin, child_margins.top])
		} else {
			child_margins.top // first child: no sibling above to collapse with
		}
		margin_box_top := flow_bottom + gap - child_margins.top
		child_box := layout_block(child, content_x, margin_box_top, width, author_rules)
		flow_bottom = margin_box_top + child_box.margin.top + child_box.border.top +
			child_box.padding.top + child_box.height + child_box.padding.bottom + child_box.border.bottom
		prev_bottom_margin = child_box.margin.bottom
		has_prev = true
		children << child_box
	}
	// Auto height spans the children's margin box (the last child's bottom margin is included; it
	// would collapse with the parent's own bottom margin only if there were no bottom border/padding
	// — parent/child collapsing is a FIXME, so we keep it inside for now).
	content_height := if has_prev { flow_bottom + prev_bottom_margin - content_y } else { 0.0 }

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
